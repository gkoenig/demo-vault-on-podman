# Quick intro into dealing with Podman

### creating containers & pods

- create a container
  sample httpd server:  

  ```bash
  podman run -dt -p 8080:8080/tcp -e HTTPD_VAR_RUN=/var/run/httpd -e HTTPD_MAIN_CONF_D_PATH=/etc/httpd/conf.d \
                  -e HTTPD_MAIN_CONF_PATH=/etc/httpd/conf \
                  -e HTTPD_CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/httpd/ \
                  registry.fedoraproject.org/f29/httpd /usr/bin/run-httpd
  ```

- create an empty pod

- create a pod including a container running an app

```bash
sudo podman run --cap-add IPC_LOCK --rm docker.io/library/vault -p 8200:8200 --pod new:vault
```

### list

- list containers:  
  
```sudo podman ps```

- list _all_ containers:  
  
```sudo podman ps -a```

- list pods and included containers:  

```sudo podman ps -a --pod```
check the output for your container running _vault_ and pick its container-id

### check

- inspect container

```sudo podman inspect <<containerid>>```

- get logs

```sudo podman logs <<containerid>>```

### managing pods

- add a container to a pod:  

``` ```

- stop a container in a pod:  
```sudo podman stop <<container-id>>```
- stop a pod:  
```sudo podman pod stop <<pod-id>>```
- start a pod again:
```sudo podman pod start <<pod-id>>```
- delete a pod:
```sudo podman pod rm <<pod-id>>```
