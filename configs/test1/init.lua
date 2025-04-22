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

    box.schema.create_space("accounts", {
        format = {
            {name = 'id', type = 'unsigned'},
            {name = 'value', type = 'any'}
        },
        if_not_exists = true,
    })
    box.space.accounts:create_index('primary', {parts = {'id'}})
    print('box.once executed')
end)

print("test 1 loaded")