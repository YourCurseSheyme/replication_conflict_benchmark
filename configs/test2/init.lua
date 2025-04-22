box.cfg({
    listen = os.getenv("TARANTOOL_LISTEN"),
    replication = {
        os.getenv("TARANTOOL_MASTER"),
        os.getenv("TARANTOOL_REPLICA")
    },
    wal_dir = os.getenv("TARANTOOL_WAL_DIR"),
    memtx_dir = os.getenv("TARANTOOL_MEMTX_DIR"),
})

box.once("schema", function()
    box.schema.user.grant('guest', 'read,write,execute', 'universe')

    box.schema.create_space("customers", {
        format = {
            {name = 'customer_id', type = 'unsigned'},
            {name = 'name', type = 'string'}
        },
        if_not_exists = true,
    })
    box.space.customers:create_index('primary', {parts = {'customer_id'}})

    box.schema.create_space("accounts", {
        format = {
            {name = 'account_id', type = 'unsigned'},
            {name = 'customer_id', type = 'unsigned'},
            {name = 'balance', type = 'number'}
        },
        if_not_exists = true,
    })
    box.space.accounts:create_index('primary', {parts = {'account_id'}})

    box.schema.create_space("operations", {
        format = {
            {name = 'operation_id', type = 'unsigned'},
            {name = 'from_acc', type = 'unsigned'},
            {name = 'to_acc', type = 'unsigned'},
            {name = 'amount', type = 'number'},
            {name = 'status', type = 'string'}
        },
        if_not_exists = true,
    })
    box.space.operations:create_index('primary', {parts = {'operation_id'}})
    print('box.once executed')
end)

print("test 2 loaded")