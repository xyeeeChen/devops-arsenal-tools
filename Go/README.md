# GO

This document records some commands for Go language.

## Update golang version

1. Uninstall old version if it is located in `/usr/local/go`.

```sh
sudo rm -rf /usr/local/go
```

2. Download [the binary release suitable](https://golang.org/dl/) for your system.

3. Extract the archive file (e.g., go1.16.5.darwin-amd64.tar.gz)

```sh
sudo tar -C /usr/local -xzf ~/Downloads/go1.16.5.darwin-amd64.tar.gz
```

4. Make sure that your PATH contains /usr/local/go/bin.

```sh
echo $PATH | grep "/usr/local/go/bin"
```

5. If not, add the end of your `~/.bashrc` or `~/.zshrc`

```sh
export PATH=$PATH:/usr/local/go/bin
```

## Update golang version of go module

1. Modify the version in go.mod

2. Run

```sh
go mod tidy
```

Update the imported modules

1. Remove the require block in the go.mod.

2. Delete go.sum

3. Run

```sh
go mod tidy
```