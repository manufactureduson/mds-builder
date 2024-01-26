FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update \
 && apt -y upgrade \
 && apt -y install build-essential  bash bc binutils build-essential bzip2 \
        cpio g++ gcc git gzip locales libncurses5-dev libdevmapper-dev \
        libsystemd-dev make mercurial whois patch perl python3 rsync sed \
        tar vim unzip wget bison flex libssl-dev libfdt-dev curl file swig\
        u-boot-tools \
    && rm -rf /var/lib/apt-lists/*


RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen

ARG UID=1000
ARG GID=1000
ARG USER=build

RUN addgroup --gid ${GID} docker
RUN useradd -d /home/${USER} -r -u ${UID} -g ${GID} ${USER}
RUN mkdir -p -m 0755 /home/${USER}
RUN chown ${USER} /home/${USER}

RUN echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER ${USER}
WORKDIR /home/${USER}
