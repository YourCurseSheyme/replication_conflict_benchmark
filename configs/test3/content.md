# Test 3

## Steps as SQL queries

1. Initial data entry under active replication

```sql
insert into rooms values (101, 'free', null);
```

2. Disconnecting replication using Tarantool as an example

```lua
original_replication = box.cfg.replication
box.cfg{replication = {}}
```

3. First node transaction

```sql
begin
insert into bookings values ('BKG-A1', 101, 'BabyBoi', 'confirmed');
update rooms set status = 'booked', ref = 'BKG-A1' where room_id = 101;
commit;
```

4. Second node transaction

```sql
begin
insert into bookings values ('BKG-B1', 101, 'BabyGirl', 'confirmed');
update rooms set status = 'booked', ref = 'BKG-B1' where room_id = 101;
commit;
```

5. Recovering replication

```lua
box.cfg{replication = original_replication}
```