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

    box.schema.create_space("rooms", {
        format = {
            {name = 'room_id', type = 'unsigned'},
            {name = 'status', type = 'string'},
            {name = 'ref', type = 'string'}
        },
        if_not_exists = true,
    })
    box.space.rooms:create_index('primary', {parts = {'room_id'}})

    box.schema.create_space("bookings", {
        format = {
            {name = 'booking_id', type = 'unsigned'},
            {name = 'room_id', type = 'unsigned'},
            {name = 'guest', type = 'string'},
            {name = 'payment_status', type = 'string'}
        },
        if_not_exists = true,
    })
    box.space.bookings:create_index('primary', {parts = {'booking_id'}})
    print('box.once executed')
end)

print("test 3 loaded")