# kafka-ctrl-docker #

Docker image with light kafka control-helper script

# Using with docker-compose #

There is an docker-compose example on `docker-compose/` path.

Example of use:

```command
cd docker-compose
docker-compose run --rm kafka-ctl
```

## Consume and produce example ##

Run this in one terminal in order to create a topic

```command
cd docker-compose
docker-compose run --rm kafka-ctl create-topic testtopic
```

Then starts the consumer

```
docker-compose run --rm kafka-ctl consume testtopic
```

Content of topic will be showed in `stdout`

In other terminal launch the consumer

```
cd docker-compose
docker-compose run --rm kafka-ctl produce testtopic
```

Data to push in topic is reading from `stdin`

## Create topic but command never ends (keep-alive)

This can be useful when you call create-topics for example in a docker-compose
with other services that require topics are created. Obviously you will need
`healthcheck` options in docker-compose and use `depends_on: service_healthy`
option.

````
cd docker-compose
docker-compose run -e KEEP_ALIVE_SLEEP_TIME=60 --rm kafka-ctl create-topic testtopic
```

## Cleaning procedure ##

**TODO**
