FROM postgres:14 as base

RUN apt-get update && \
  apt-get install -y \
    git \
    curl \
    wget \
    python2 \
    build-essential \
    ninja-build \
    pkg-config \
    libtinfo5 \
    libssl-dev\
    libc++abi-dev \
    postgresql-server-dev-${PG_MAJOR} \
  && update-alternatives --install /usr/bin/python python /usr/bin/python2 1 \
  && ln -s /usr/lib/postgresql/${PG_MAJOR} /usr/local/postgres64 \
  && mkdir -p /src
COPY ./ /src

FROM base as ap_pgutils
RUN cd /src/ap_pgutils/ && make -j $(nproc) && make install

FROM base as wal2json
RUN cd /src/wal2json/ && USE_PGXS=1 make -j $(nproc) && USE_PGXS=1 make install

FROM base as plv8
RUN cd /src/plv8 && \
  sed Makefile -e 's/-lc++/ /' > Makefile.out && \
  mv Makefile.out Makefile && \
  make && make install

FROM postgres:14

COPY --from=base /src/initconf.sh /docker-entrypoint-initdb.d/

ENV PLV8_VERSION 3.0.0

RUN mkdir -p \
  /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/ap_pgutils/ \
  /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/wal2json/ \
  /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/plv8-${PLV8_VERSION}/

COPY --from=ap_pgutils /usr/lib/postgresql/${PG_MAJOR}/lib/ap_pgutils.so /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=ap_pgutils /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/ap_pgutils.* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/
COPY --from=ap_pgutils /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/ap_pgutils/* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/ap_pgutils/
COPY --from=ap_pgutils /usr/share/postgresql/${PG_MAJOR}/extension/ap_pgutils* /usr/share/postgresql/${PG_MAJOR}/extension/

COPY --from=wal2json /usr/lib/postgresql/${PG_MAJOR}/lib/wal2json.so /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=wal2json /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/wal2json.* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/
COPY --from=wal2json /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/wal2json/* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/wal2json/

COPY --from=plv8 /usr/lib/postgresql/${PG_MAJOR}/lib/plv8* /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=plv8 /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/plv8* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/
COPY --from=plv8 /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/plv8-${PLV8_VERSION}/* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/plv8-${PLV8_VERSION}/
COPY --from=plv8 /usr/share/postgresql/${PG_MAJOR}/extension/plv8* /usr/share/postgresql/${PG_MAJOR}/extension/
