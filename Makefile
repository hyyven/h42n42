# init:
# 	docker build -f Dockerfile.init -t h42n42-init .
# 	docker run --rm -v "$$(pwd):/main" -u root h42n42-init
# 	docker run --rm --entrypoint /bin/sh -v "$$(pwd):/main" -u root h42n42-init -c "chown -R root:root /main/h42n42"

# delete_ocsigen:
# 	docker build -f Dockerfile.init -t h42n42-init .
# 	docker run --rm --entrypoint /bin/sh -v "$$(pwd):/tmp" -w /tmp -u root h42n42-init -c "rm -rf h42n42"

BIN = _build/default/src/h42n42_main.bc
SRCS = $(shell find src -type f)

all: $(BIN)

run: $(BIN)
	docker compose up -d

$(BIN): $(SRCS) Dockerfile docker-compose.yml
	docker compose up -d --build	

clean:
	docker compose run --rm app sh -c 'eval $$(opam env) && make clean'

fclean: clean
	docker compose down --rmi all -v --remove-orphans

re: fclean all

stop:
	docker compose down

debug:
	docker compose up

