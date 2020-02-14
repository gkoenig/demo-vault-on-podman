listener "tcp" {
    address = "0.0.0.0:8200"
    tls_disable = 1
}
storage "file" {
    path = "/vault/file"
}
disable_mlock = true
api_addr = "http://0.0.0.0:8200"
ui=true
