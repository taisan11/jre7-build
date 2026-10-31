# Legacy build toolchain: DO NOT run this image as a production service.
# Trusty provides OpenJDK 6 and GCC 4.8 for compiling the OpenJDK 7u forest.
FROM ubuntu:14.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C \
    LC_ALL=C

# Trusty packages are currently hosted on the main Ubuntu archive, not
# old-releases. Keep apt signature verification enabled.
RUN printf '%s\n' \
      'deb http://archive.ubuntu.com/ubuntu/ trusty main restricted universe multiverse' \
      'deb http://archive.ubuntu.com/ubuntu/ trusty-updates main restricted universe multiverse' \
      'deb http://archive.ubuntu.com/ubuntu/ trusty-security main restricted universe multiverse' \
      > /etc/apt/sources.list \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends \
      openjdk-6-jdk gcc-4.8 g++-4.8 make ant \
      build-essential zip unzip file ca-certificates \
      libfreetype6-dev libfontconfig1-dev libasound2-dev libcups2-dev \
      libx11-dev libxext-dev libxrender-dev libxtst-dev libxi-dev \
      libxrandr-dev libxt-dev \
 && rm -rf /var/lib/apt/lists/*

COPY build-jdk.sh /opt/build-jdk.sh
RUN chmod 0755 /opt/build-jdk.sh
WORKDIR /work/openjdk
