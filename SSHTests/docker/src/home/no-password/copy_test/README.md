
```sh
docker build -t sshd .
```

```sh
docker run --rm --init -p 2222:22 sshd
```

with custom port

```sh
docker run --rm --init -p 2223:23 sshd -p 23
```