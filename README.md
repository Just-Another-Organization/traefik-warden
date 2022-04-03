# JA-Traefik-Warden

Warden is a Just Another project that helps to manage services through [Traefik](https://github.com/traefik/traefik).

## Why choose Traefik?
> Traefik (pronounced traffic) is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy. Traefik integrates with your existing infrastructure components (Docker, Swarm mode, Kubernetes, Marathon, Consul, Etcd, Rancher, Amazon ECS, ...) and configures itself automatically and dynamically. Pointing Traefik at your orchestrator should be the only configuration step you need.

## Services deploy with Traefik
To manage services deploy through Traefik and Docker you need to configure your `docker-compose.yaml` and set labels and networks configurations as shown in the [official documentation](https://doc.traefik.io/traefik/user-guides/docker-compose/basic-example/). 

# Why use Warden?
Warden helps to manage services deploy without changes is your `docker-compose.yaml`. This may be very useful to automate services deployment through pipelines or automatic deployment systems/scripts, also not modifying any file in the repositories of the project helps to create clean environments and projects structures.

# How Warden work?
First of all, you need to define a service configuration writing it on your own or starting from a template. When invoked, Warden simply creates a copy on the fly of the `docker-compose.yaml` that you want to deploy, and injects the service configurations in the copy. After doing this, Warden starts the services defined in the `docker-compose.yaml` and cleans the environment removing the copy.

## Install Warden
First of all install the dependencies.

### Install the dependencies
The only dependency to install is `yq` (version v2).

```shell
# Use pip packege manager to simply install yq
pip install yq
```

To install Warden simply clone the repository and run the `install.sh` script.
```shell
git clone https://github.com/Just-Another-Organization/JA-Traefik-Warder.git
cd JA-Traefik-Warder/
./install.sh
```
The installation script install the `warden` command and copy the `services` and `templates` directories in the `WARDEN_ROOT`. If no `WARDEN_ROOT` environment varibale is set the default value and location will be set to `$HOME/.warden`. If you want to set a different location you can define the variable before run the installation script.

```shell
WARDEN_ROOT=/your/custom/location/ ./install.sh  
```

## Using Warden
You can use Warden to start and stop services starting from a `docker-compose.yaml`. Ater defined the service configuration you can start the service through Traefik entering in the directory where is your `docker-compose.yaml` and using the `start` mode.

```shell
warden start my_service
```
Otherwise you can define the `docker-compose.yaml` using the `-f` option.

```shell
warden start my_service -f /your/path/to/docker-compose.yaml
```
To stop a running service simply use the `stop` mode.

```shell
warden stop my_service
# Or defining the `docker-compose.yaml` using the `-f` option.
warden stop my_service -f /your/path/to/docker-compose.yaml
```

If you want to only generate the `docker-compose.yaml` with the Warden configuration injected use the `generate` mode. This will create a `warden-docker-compose.yaml` that you can easly use to start and stop the services. 

## Using templates
Templates are YAML files that you can creates and use to define new services configuration. Templates are stored in the `WARDEN_ROOT/templates/` directory. 

To create a template you need to define `placeholders` and `content` properties. You can define placeholders name and the default value under the `placeholder` property. When Warden creates a configuration each placeholder in the `content` property will be replaced with a value. The value of a pleceholder can be set using environment variable when the `create` mode is called, if no value is set the replaced value will be the default value.     

Here is an example:

```yaml
# Template example: $WARDEN_ROOT/templates/my_template.yaml
placeholders:
  - PLACEHOLDER_NAME: default_value

content:
  services:
    service_name:
      labels:
        your_rule.PLACEHOLDER_NAME.example: rule_value.PLACEHOLDER_NAME.example
```

```shell
PLACEHOLDER_NAME=value_to_replace \
warden create -s my_service -t my_template
```

```yaml
# Service config created using template: $WARDEN_ROOT/services/my_service.yaml
services:
  service_name:
    labels:
      your_rule.value_to_replace.example: rule_value.value_to_replace.example
```

Also you can create your own templates starting from the `default.yaml` template. 

```yaml
# $WARDEN_ROOT/templates/default.yaml
placeholders:
  - SERVICE_NAME_PLACEHOLDER: service
  - DOMAIN_PLACEHOLDER: example.com
  - PORT_PLACEHOLDER: 80

content:
  services:
    app:
      labels:
        traefik.http.routers.SERVICE_NAME_PLACEHOLDER.rule: Host(`SERVICE_NAME_PLACEHOLDER.DOMAIN_PLACEHOLDER`)
        traefik.http.routers.SERVICE_NAME_PLACEHOLDER.rule: HostHeader(`SERVICE_NAME_PLACEHOLDER.DOMAIN_PLACEHOLDER`)
        traefik.http.routers.SERVICE_NAME_PLACEHOLDER.entrypoints: https
        traefik.http.routers.SERVICE_NAME_PLACEHOLDER.tls: true
        # Middlewares
        traefik.http.routers.SERVICE_NAME_PLACEHOLDER.middlewares: chain-no-auth@file
        ## HTTP Services
        traefik.http.routers.SERVICE_NAME_PLACEHOLDER.service: SERVICE_NAME_PLACEHOLDER-svc
        traefik.http.services.SERVICE_NAME_PLACEHOLDER-svc.loadbalancer.server.port: PORT_PLACEHOLDER
```
Using the default template will generate a service configuration like the following:

```shell
SERVICE_NAME_PLACEHOLDER=example_service \
DOMAIN_PLACEHOLDER=example.com \
warden create -s example_service
```
Please note that `PORT_PLACEHOLDER` variable is not set so the default value (80) will be used. The service configuration created will be:  

```yaml
# $WARDEN_ROOT/services/example_service.yaml
services:
  app:
    labels:
      traefik.http.routers.example_service.rule: HostHeader(`example_service.example.com`)
      traefik.http.routers.example_service.entrypoints: https
      traefik.http.routers.example_service.tls: true
      traefik.http.routers.example_service.middlewares: chain-no-auth@file
      traefik.http.routers.example_service.service: example_service-svc
      traefik.http.services.example_service-svc.loadbalancer.server.port: 80
```
