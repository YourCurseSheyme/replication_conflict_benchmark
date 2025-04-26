
-- Needed modules and initializations

local net_box = require('net.box')
local xlog = require('xlog')

local M = {
    connect_timeout = 3,
    max_retries = 5,
    retry_delay = 0.1,
    user = 'guest',
    password = '',
}

-- Cache and operating data

checking_tuple = nil

local box_info = box.info
local box_cfg = box.cfg
local box_space = box.space

local state = {
    space_id = nil,
    chosen_node = nil,
}

-- Service functions

M.get_uri = function(node_id)
    if node_id == box_info.id then
        for _, uri in ipairs(box_cfg.replication) do
            if string.match(tostring(uri), tostring(box_cfg.listen)) then
                return uri
            end
        end
    else
        local replica = box_info.replication[node_id]
        if replica and replica.upstream then
            return replica.upstream.peer
        end
    end
end

M.print_table = function(data)
    if type(data) ~= "table" then
        return
    end

    print("+---------------")
    for key, value in pairs(data) do
        if type(value) == "table" then
            print("| " .. key .. ":")
            M.print_table(value)
            print("+---------------")
        else
            print("| " .. key .. ": " .. tostring(value))
        end
    end
end

M.clean_up = function()
    state.space_id = nil
    state.chosen_node = nil
end

-- Finding conflicting values

M.process_xlogs = function(lsn)
    local fio = require('fio')
    local xlog = require('xlog')
    local original_dir = fio.cwd()
    fio.chdir(box.cfg.wal_dir)
    local cwd = fio.listdir(fio.cwd())
    table.sort(cwd)
    for _, filename in ipairs(cwd) do
        if string.match(filename, ".xlog") then
            for _, trans in xlog.pairs(filename) do
                if trans.HEADER and trans.HEADER.lsn == lsn then
                    fio.chdir(original_dir)
                    return trans
                end
            end
        end
    end
    fio.chdir(original_dir)
    return 1
end

M.remote_eval = function(uri, func, args)
    local connect = net_box.connect(uri)
    if connect and connect:is_connected() then
        local result = connect:eval(func, args)
        connect:close()
        return result
    end
    error("Failed to evaluate script on " .. uri .. ": connection failed")
end

M.get_trans = function(node_id, lsn)
    local uri = M.get_uri(node_id)
    local func = string.dump(M.process_xlogs)
    local transaction = M.remote_eval(uri, func, {lsn})
    while type(transaction) == "number" do
        transaction = M.remote_eval(uri, func, {lsn - 1})
    end
    return transaction
end

-- Processing conflict

M.detect_conflict = function()
    local local_trans = 0
    local conflict_found = false
    local nodes_info = {}

    for id in pairs(box_info.replication) do
        local replica = box_info.replication[id]
        local node_id = replica.id
        local node_uri = M.get_uri(node_id)

        if node_id == box_info.id then
            local_trans = M.get_trans(node_id, replica.lsn)
            table.insert(nodes_info, {
                id = node_id,
                uri = node_uri,
                trans = local_trans,
            })
        else
            local upstream_status = replica.upstream and replica.upstream.status
            local downstream_status = replica.downstream and replica.downstream.status

            if upstream_status == "stopped" or downstream_status == "stopped" then
                local trans = M.get_trans(node_id, replica.lsn + 1)
                table.insert(nodes_info, {
                    id = node_id,
                    uri = node_uri,
                    trans = trans,
                })
                conflict_found = true
            else
                table.insert(nodes_info, {
                    id = node_id,
                    uri = node_uri,
                    trans = nil,
                })
            end
        end
    end

    if conflict_found then
        for _, node in ipairs(nodes_info) do
            if node.trans then
                print(node.id .. ". at " .. node.uri)
                M.print_table(node.trans)
                print("\n")
            end
        end
    else
        print("Warning: No conflicting transactions detected between nodes")
        print("List of URIs for each node: ")
        for _, node in ipairs(nodes_info) do
            print("Node " .. node.id .. " at " .. node.uri)
        end
    end

    return conflict_found, local_trans, nodes_info
end

-- Running conflict resolving

M.apply_resolution = function(space_id)
    local new_trigger = loadstring([[function resolving_trigger(old, new, space, op)
            if new == nil then
                return
            end
            if old == nul then
                return new
            end
            if op == 'INSERT' then
                local key_parts = box.space[space].index[0].parts
                -- checked  if all same key_paires
                for key in pairs(key_parts) do
                    local fieldno = box.space[space].index[0].parts[key].fieldno
                    if old[fieldno] == new[fieldno] then
                        return box.tuple.new(checking_tuple)
                    end
                end
                return old
            end
            return
        end
    ]])
    local replication_backup = box.cfg.replication
    box.cfg({replication = {}})
    new_trigger()
    box.space[space_id]:before_replace(resolving_trigger)
    box.cfg({replication = replication_backup })
end

M.resolve_conflict = function()
    print("---")
    if state.chosen_node == nil then
        print("Invalid chosen node value")
        print("Please use function \"conflict()\" firstly")
        return
    end
    print("Starting resolving conflict by updating nodes to " .. state.chosen_node .. ": " .. M.get_uri(state.chosen_node) .. " data")

    local uri = M.get_uri(state.chosen_node)
    local lsn = box.info.replication[state.chosen_node].lsn
    if state.chosen_node ~= box.info.id then
        lsn = lsn + 1
    end
    checking_tuple = M.get_trans(state.chosen_node, lsn).BODY.tuple

    if not checking_tuple then
        error("Failed to get reference tuple")
    end

    for node_id in pairs(box.info.replication) do
        if node_id ~= box_info.id then
            uri = M.get_uri(node_id)
            M.remote_eval(uri, [[
                checking_tuple = ...
            ]], {checking_tuple})
            M.remote_eval(uri, string.dump(M.apply_resolution), {state.space_id})
        end
    end
    M.apply_resolution(state.space_id)
    print("Successful resolving")
    M.clean_up()
    print("Data is up to date")
end

-- Running conflict output

M.fetch_conflict = function()
    print("---")
    local conflict_found, local_trans, nodes_info = M.detect_conflict()

    if conflict_found then
        local node_choices = {}
        for _, node in ipairs(nodes_info) do
            if node.trans then
                table.insert(node_choices, node.id)
            end
        end

        print("Please choose tuple to replace each conflicting other:")
        print("Available node IDs: " .. table.concat(node_choices, ", "))
        if state.chosen_node ~= nil then
            print("You current choice is: " .. state.chosen_node)
        end
        print("Enter 0, if you do not want to choose now or change your mind")

        while true do
            state.chosen_node = io.read("*n")
            if state.chosen_node == 0 then
                print("No node chosen. Exiting")
                return
            end
            local valid = false
            for _, nid in ipairs(node_choices) do
                if nid == state.chosen_node then
                    valid = true
                    break
                end
            end
            if not valid then
                print("Invalid choice. Please try again")
                print("Available node IDs: " .. table.concat(node_choices, ", ") .. ". Enter 0 to cancel")
            else
                break
            end
        end
        print("Selected node id: " .. state.chosen_node)

        state.space_id = local_trans.BODY.space_id

        print("If you wish to resolve conflict, run additional function \"resolve_conflict()\"")
        print("Also if you wish to reselect preferred node, reuse function \"fetch_conflict()\"")
    else
        print("No conflicts to resolve")
    end
end

return M
