FROM alpine:3.17.0
MAINTAINER Tom Mitchell "tom@tom.org"
# mods by mju 21/02/2023

ENV WEEWX_VERSION=4.10.0
ENV HOME=/home/weewx
ENV TZ=America/New_York

#wget http://www.weewx.com/downloads/released_versions/weewx-4.9.1.tar.gz -O /tmp/weewx.tgz \
#      && cd /tmp && tar zxvf /tmp/weewx*.tgz \
#      && cd weewx-* && python3 ./setup.py build && python3 ./setup.py install --no-prompt \

ADD dist/weewx-$WEEWX_VERSION /tmp/weewx/
COPY conf-fragments/ /tmp/
RUN apk add --update --no-cache --virtual deps gcc zlib-dev jpeg-dev python3-dev build-base linux-headers freetype-dev py3-pip alpine-conf \
    && apk add --no-cache python3 py3-pyserial py3-usb py3-pymysql sqlite wget rsync openssh tzdata wheel\
    && ln -sf python3 /usr/bin/python \
    && pip3 install --no-cache --upgrade Cheetah3 Pillow image pyephem setuptools requests dnspython paho-mqtt configobj \
    && cd /tmp/weewx \
    && python3 ./setup.py build \
    && python3 ./setup.py install --no-prompt \
    && mkdir -p /var/log/weewx /tmp/weewx /home/weewx/public_html \
    && rm -rf /tmp/weewx \
    && apk del deps \
    && cat /tmp/*.conf >> /home/weewx/weewx.conf \
    && rm -rf /tmp/*.conf \
    && sed -i -e s:unspecified:Simulator: /home/weewx/weewx.conf

# mju enhancements here to enable mount of /data externally

VOLUME ["/data"]

RUN cd /home/weewx \
  && mkdir -p /data \
  && cp -r * /data

ENV PATH="/opt/venv/bin:$PATH"

CMD ["/home/weewx/bin/weewxd", "/home/weewx/weewx.conf"]
