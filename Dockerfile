FROM debian:sid
MAINTAINER Rafael Römhild <rafael@roemhild.de>

ENV EJABBERD_BRANCH=18.1.0 \
    EJABBERD_USER=ejabberd \
    EJABBERD_HTTPS=true \
    EJABBERD_STARTTLS=true \
    EJABBERD_S2S_SSL=true \
    EJABBERD_HOME=/opt/ejabberd \
    EJABBERD_DEBUG_MODE=false \
    HOME=$EJABBERD_HOME \
    PATH=$EJABBERD_HOME/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin \
    DEBIAN_FRONTEND=noninteractive \
    XMPP_DOMAIN=localhost \
    LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

# Add ejabberd user and group
RUN groupadd -r $EJABBERD_USER \
    && useradd -r -m \
       -g $EJABBERD_USER \
       -d $EJABBERD_HOME \
       $EJABBERD_USER

# Install packages and perform cleanup
RUN set -x \
    && buildDeps=' \
        git-core \
        build-essential \
        automake \
        libssl-dev \
        zlib1g-dev \
        libexpat-dev \
        libyaml-dev \
        libsqlite3-dev \
        erlang-src erlang-dev \
        libgd-dev \
        libwebp-dev \
    ' \
    && requiredAptPackages=' \
        wget \
        dirmngr \
        gpg-agent \
        locales \
        ldnsutils \
        python2.7 \
        python-jinja2 \
        ca-certificates \
        libyaml-0-2 \
        rebar \
        erlang-asn1 \
        erlang-base \
        erlang-crypto \
        erlang-dev \
        erlang-eunit \
        erlang-fs-listener \
        erlang-inets \
        erlang-jiffy \
        erlang-jose \
        erlang-lager \
        erlang-mnesia \
        erlang-p1-cache-tab \
        erlang-p1-eimp \
        erlang-p1-iconv \
        erlang-p1-mysql \
        erlang-p1-oauth2 \
        erlang-p1-pam \
        erlang-p1-pgsql \
        erlang-p1-sip \
        erlang-p1-sqlite3 \
        erlang-p1-stringprep \
        erlang-p1-stun \
        erlang-p1-tls \
        erlang-p1-utils \
        erlang-p1-xml \
        erlang-p1-xmpp \
        erlang-p1-yaml \
        erlang-p1-zlib \
        erlang-parsetools \
        erlang-redis-client \
        erlang-ssl \
        erlang-xmerl \
        python-mysqldb \
        imagemagick \
        libgd3 \
        libwebp6 \
    ' \
    && apt-get update \
    && apt-get install -y $buildDeps $requiredAptPackages --no-install-recommends \
    && dpkg-reconfigure locales && \
        locale-gen C.UTF-8 \
    && /usr/sbin/update-locale LANG=C.UTF-8 \
    && echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen \
    && locale-gen \
    && cd /tmp \
    && git clone https://github.com/processone/ejabberd.git \
        --branch $EJABBERD_BRANCH --single-branch --depth=1 \
    && cd ejabberd \
    && chmod +x ./autogen.sh \
    && ./autogen.sh \
    && ./configure --enable-user=$EJABBERD_USER \
        --enable-all \
        --disable-tools \
        --disable-pam \
    && make debug=$EJABBERD_DEBUG_MODE \
    && make install \
    && mkdir $EJABBERD_HOME/ssl \
    && mkdir $EJABBERD_HOME/conf \
    && mkdir $EJABBERD_HOME/backup \
    && mkdir $EJABBERD_HOME/upload \
    && mkdir $EJABBERD_HOME/database \
    && mkdir $EJABBERD_HOME/module_source \
    && cd $EJABBERD_HOME \
    && rm -rf /tmp/ejabberd \
    && rm -rf /etc/ejabberd \
    && ln -sf $EJABBERD_HOME/conf /etc/ejabberd \
    && rm -rf /usr/local/etc/ejabberd \
    && ln -sf $EJABBERD_HOME/conf /usr/local/etc/ejabberd \
    && chown -R $EJABBERD_USER: $EJABBERD_HOME \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge -y --auto-remove $buildDeps

RUN wget -P /usr/local/share/ca-certificates/cacert.org http://www.cacert.org/certs/root.crt http://www.cacert.org/certs/class3.crt; \
    update-ca-certificates

ENV GOSU_VERSION 1.10
RUN set -ex; \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    wget -O /usr/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    \
# verify the signature
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/bin/gosu.asc /usr/bin/gosu; \
    rm -r "$GNUPGHOME" /usr/bin/gosu.asc; \
    \
    chmod +sx /usr/bin/gosu; \
    gosu nobody true;

# Create logging directories
RUN mkdir -p /var/log/ejabberd
RUN touch /var/log/ejabberd/crash.log /var/log/ejabberd/error.log /var/log/ejabberd/erlang.log

# Wrapper for setting config on disk from environment
# allows setting things like XMPP domain at runtime
ADD ./run.sh /sbin/run

# Add run scripts
ADD ./scripts $EJABBERD_HOME/scripts
ADD https://raw.githubusercontent.com/rankenstein/ejabberd-auth-mysql/master/auth_mysql.py $EJABBERD_HOME/scripts/lib/auth_mysql.py
RUN chmod a+rx $EJABBERD_HOME/scripts/lib/auth_mysql.py
RUN chmod +x /usr/local/lib/eimp*/priv/bin/eimp

# Add config templates
ADD ./conf /opt/ejabberd/conf

# Continue as user
USER $EJABBERD_USER

# Set workdir to ejabberd root
WORKDIR $EJABBERD_HOME

VOLUME ["$EJABBERD_HOME/database", "$EJABBERD_HOME/ssl", "$EJABBERD_HOME/backup", "$EJABBERD_HOME/upload"]
EXPOSE 4560 5222 5269 5280 5443

CMD ["start"]
ENTRYPOINT ["run"]
