FROM postgres:13 as base

RUN apt-get update && \
  apt-get install -y \
    git \
    curl \
    wget \
    python \
    build-essential \
    ninja-build \
    pkg-config \
    libtinfo5 \
    libssl-dev \
    postgresql-server-dev-${PG_MAJOR} && \
    ln -s /usr/lib/postgresql/${PG_MAJOR} /usr/local/postgres64 && \
    mkdir -p /src
COPY ./ /src

RUN cd /src/ap_pgutils/ && make -j $(nproc) && make install
RUN cd /src/wal2json/ && USE_PGXS=1 make -j $(nproc) && USE_PGXS=1 make install
RUN cd /src/plv8 && \
  sed Makefile -e 's/-lc++/ /' > Makefile.out && \
  mv Makefile.out Makefile && \
  make v8 && make static -j $(nproc) && make install

FROM postgres:13

ENV PLV8_VERSION 3.0alpha

RUN mkdir -p \
  /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/ap_pgutils/ \
  /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/wal2json/ \
  /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/plv8-${PLV8_VERSION}/

COPY --from=base /usr/lib/postgresql/${PG_MAJOR}/lib/ap_pgutils.so /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=base /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/ap_pgutils.* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/
COPY --from=base /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/ap_pgutils/* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/ap_pgutils/
COPY --from=base /usr/share/postgresql/${PG_MAJOR}/extension/ap_pgutils* /usr/share/postgresql/${PG_MAJOR}/extension/

COPY --from=base /usr/lib/postgresql/${PG_MAJOR}/lib/wal2json.so /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=base /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/wal2json.* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/
COPY --from=base /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/wal2json/* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/wal2json/

COPY --from=base /usr/lib/postgresql/${PG_MAJOR}/lib/plv8* /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=base /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/plv8* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/
COPY --from=base /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/plv8-${PLV8_VERSION}/* /usr/lib/postgresql/${PG_MAJOR}/lib/bitcode/plv8-${PLV8_VERSION}/
COPY --from=base /usr/share/postgresql/${PG_MAJOR}/extension/plv8* /usr/share/postgresql/${PG_MAJOR}/extension/

COPY --from=base /src/initconf.sh /docker-entrypoint-initdb.d/
