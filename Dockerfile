#LARGOWEATHER.COM Docker Image
#LAST UPDATED: 07-12-2022 4:50PM
#
#NOTE: Directories that you need to map to in the container:
#   /home/weewx/public_html
#   /home/weewx/archive
#   /home/weewx/config
#   

#==== WEEWX_OS_BASE =====
FROM python:3.10.4-slim-bullseye as weewx_os_base

#Docker Labels for tracking purposes.
LABEL maintainer="doug@dougjenkins.com"
LABEL org.opencontainers.image.authors="doug@dougjenkins,com"
LABEL org.opencontainers.image.url="largoweather.com"
LABEL org.opencontainers.image.version="4.10.1"
LABEL org.opencontainers.image.title="WeeWX Docker Image"
LABEL org.opencontainers.image.source="https://github.com/ddjlabs/largoweather_weewx_setup"

#Environmental Variables
ENV TZ=America/New_York
ENV WEEWX_VERSION="4.10.1"

# BelcherTown Skin Tag: This is referencing a custom release at github.com/ddjlabs/weewx-belchertown project
ENV BELCHERTOWN_SKIN_TAG="lw-belchertown-1.4"

#WeeWX Forecast Tag: This is referencing a custom release at https://github.com/ddjlabs/weewx-forecast
ENV WEEWX_FORECAST_TAG="v3.4.0b11"  
ENV WEEWX_DAVISHEALTHAPI_TAG="v0.10-beta"
ENV WEEWX_AIRLINK_TAG="lw-airlink-v1.2"






#Setup work directory and copy over the requirements.txt and the app folder (including its contents)
WORKDIR /home/weewx
RUN apt update && apt upgrade -y && \
        apt install -y wget curl tzdata apt-transport-https python-is-python3 python3-pip \
        python3-configobj python3-pil python3-serial python3-usb python3-mysqldb \
        python3-cheetah python3-ephem mariadb-client sqlite3 xtide xtide-data && \
        apt-get clean autoclean && \
        apt-get autoremove --yes && \
        rm -rf /var/lib/{apt,dpkg,cache,log}/

#Set the Container to the local timezone, that way the data will be written in the desired timezone provided by the docker run definition.
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone


# ===== WEEWX APP BASE STAGE : This downloads WeeWX base and installs it with the correct Python PIP packages. =====
FROM weewx_os_base as weewx_app_base
WORKDIR /home/weewx
COPY requirements.txt .

#Run PIP and install the required python packages. This maybe overkill, but it solves many many problems!
RUN pip3 install -r requirements.txt --compile --no-cache-dir && \
    cd /tmp && \
    wget https://weewx.com/downloads/weewx-$WEEWX_VERSION.tar.gz && \
    tar xvfz weewx-$WEEWX_VERSION.tar.gz && \
    rm weewx-$WEEWX_VERSION.tar.gz && \
    cd /tmp/weewx-$WEEWX_VERSION && \
    python3 ./setup.py build && \
    python3 ./setup.py install --no-prompt && \
    cd /tmp && \
    rm -rf /tmp/weewx-$WEEWX_VERSION && \
    mkdir /home/weewx/config && \
    mkdir /home/weewx/public_html && \
    mkdir /home/weewx/archive

# ==== weewx_extensions stage: This downloads and installs all appropriate WeeWX Extensions =====
FROM weewx_app_base as weewx_extensions
WORKDIR /home/weewx

# --- install WeeWX WeatherLink Live Driver ---
RUN cd /tmp && \
    wget -O /tmp/weewx-weatherlink-live.tar.xz https://github.com/michael-slx/weewx-weatherlink-live/releases/download/v1.0.11/weewx-weatherlink-live-v1.0.11.tar.xz && \
    /home/weewx/bin/wee_extension --install=/tmp/weewx-weatherlink-live.tar.xz && \
    rm -rf /tmp/weewx-weatherlink-live.tar.xz 

# --- install WeeWX AirLink Driver ---
RUN cd /tmp && \
    wget -O /tmp/weewx-airlink.zip https://github.com/ddjlabs/weewx-airlink/archive/refs/tags/$WEEWX_AIRLINK_TAG.zip && \
    /home/weewx/bin/wee_extension --install=/tmp/weewx-airlink.zip && \
    rm -rf /tmp/weewx-airlink.zip

# --- Install Belchertown WeeWX Skin (Using a custom Belchertown skin tag Release from ddjlabs/weewx-belchertown project) ---
RUN cd /tmp && \
    wget -O /tmp/belchertown-skin.zip https://github.com/ddjlabs/weewx-belchertown/archive/refs/tags/$BELCHERTOWN_SKIN_TAG.zip && \
    /home/weewx/bin/wee_extension --install=/tmp/belchertown-skin.zip && \
    rm -rf /tmp/belchertown-skin.zip

# --- Install Davis Health API Checker ---
RUN cd /tmp && \
    wget -O /tmp/davishealthapi.zip https://github.com/ddjlabs/weewx-davishealthapi/archive/refs/tags/$WEEWX_DAVISHEALTHAPI_TAG.zip && \
    /home/weewx/bin/wee_extension --install=/tmp/davishealthapi.zip && \
    rm -rf /tmp/davishealthapi.zip


# --- Install WeeWX Forecast Module ---
RUN cd /tmp && \
    wget -O /tmp/weewx-forecast.zip https://github.com/ddjlabs/weewx-forecast/archive/refs/tags/$WEEWX_FORECAST_TAG.zip && \
    /home/weewx/bin/wee_extension --install=/tmp/weewx-forecast.zip && \
    rm -rf /tmp/weewx-forecast.zip

# --- Install MQTT Driver for real time updates for Belchertown ---
RUN cd /tmp && \
    wget -O /tmp/weewx-mqtt.zip https://github.com/matthewwall/weewx-mqtt/archive/master.zip && \
    /home/weewx/bin/wee_extension --install=/tmp/weewx-mqtt.zip && \
    rm -rf /tmp/weewx-mqtt.zip

# --- Install cmon ---
RUN cd /tmp && \
    wget -O /tmp/weewx-cmon.zip https://github.com/matthewwall/weewx-cmon/archive/master.zip && \
    /home/weewx/bin/wee_extension --install=/tmp/weewx-cmon.zip && \
    rm -rf /tmp/weewx-cmon.zip

# --- Install Windy REST API ---
RUN cd /tmp && \
    wget -O /tmp/weewx-windy.zip https://github.com/matthewwall/weewx-windy/archive/master.zip && \
    /home/weewx/bin/wee_extension --install=/tmp/weewx-windy.zip && \
    rm -rf /tmp/weewx-windy.zip




# ====== FINAL IMAGE BUILD STAGE =====
FROM weewx_extensions
WORKDIR /home/weewx

#Copy All image assets that are associated with LargoWeather.com to the Belchertown Images folder.
# removed by mju COPY ${PWD}/skin-assets/* /home/weewx/skins/Belchertown/images

#Copy the WeeWX.conf file as a template just in case we need to reference it after the container is built.
# removed by mju RUN cd /home/weewx && \
#   cp /home/weewx/weewx.conf /home/weewx/weewx.conf.template && \
#    rm /home/weewx/weewx.conf

#Copy the Docker Project's weewx config files to the config folder.
# COPY ${PWD}/weewx.conf /home/weewx/config    

#Execute the Run WeeWX executable program.
ENTRYPOINT ["/home/weewx/bin/weewxd", "--config","/home/weewx/config/weewx.conf"]