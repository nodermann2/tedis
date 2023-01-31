# Tedis
Real-time key-value storage based on Tarantool.

SET
```
tarantool> SET('hello', 'world')

---
- ['hello', 'world', 0]
...
```

SETEX (SET + EXPIRE)
```
tarantool> SET('hello', 'world', 500)

---
- ['hello', 'world', 1594732465]
...
```

GET
```
tarantool> GET('hello')
---
- world
...
```

EXPIRE
```
tarantool> EXPIRE('hello', 300)
---
- ['hello', 'world', 1594732866]
...
```

TTL
```
tarantool> TTL('hello')
---
- 250
...
```
DELETE
```
tarantool> DEL('hello')
---
- ['hello', 'world', 1594732866]
...

```
