FROM ocaml/opam:debian-ocaml-5.2

RUN sudo apt-get -y update && sudo apt-get -y install \
    nodejs \
    npm \
    zlib1g-dev \
    libgmp-dev \
    pkg-config \
    libsqlite3-dev \
    && sudo apt-get clean \
    && opam install -y ocsigen-start ocsipersist-sqlite-config

WORKDIR /opt/app

COPY --chown=opam:opam . /opt/app/

RUN cp eliom_Makefiles/Makefile .

RUN --mount=type=cache,target=/opt/app/_build,uid=1000,gid=1000 \
    eval $(opam env) && make byte

EXPOSE 8080

CMD ["sh", "-c", "eval $(opam env) && make test.byte"]