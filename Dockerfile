FROM --platform=linux/amd64 nvidia/cuda:12.1.1-base-ubuntu22.04

SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

RUN apt update
RUN apt upgrade -y
RUN apt-get update && apt-get install -y --no-install-recommends \
		apt-utils \
        build-essential \
        pkg-config \
        rsync \
        software-properties-common \
        unzip \
        zip \
        zlib1g-dev \
        wget \
		curl \
        git \
		git-lfs \
		vim-gtk \
		virtualenv \
		tzdata \
        libgl1-mesa-glx \
		sudo \
		libncurses-dev \
        && \
	apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH /usr/local/cuda/lib64:$LD_LIBRARY_PATH
ENV PATH /usr/local/cuda/bin:$PATH
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN git lfs install

### Install zsh 5.9 (apt install zsh version may be outdated)
ENV ZSH_SRC_NAME $HOME/bin/zsh.tar.xz
ENV ZSH_PACK_DIR $HOME/bin/zsh
ENV ZSH_LINK "https://sourceforge.net/projects/zsh/files/latest/download"

RUN mkdir -p "$ZSH_PACK_DIR"
RUN curl -Lo "$ZSH_SRC_NAME" "$ZSH_LINK"

RUN tar xJvf "$ZSH_SRC_NAME" -C "$ZSH_PACK_DIR" --strip-components 1

RUN $ZSH_PACK_DIR/configure --without-tcsetpgrp
RUN make -j && make install

RUN \rm "$ZSH_SRC_NAME"
RUN \rm -rf "$ZSH_PACK_DIR"
RUN ln -s /usr/local/bin/zsh /bin

# RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
#     && bash Miniconda3-latest-Linux-x86_64.sh -b \
#     && rm Miniconda3-latest-Linux-x86_64.sh
#
# SHELL ["/root/miniconda3/bin/conda", "run", "-n", "base", "/bin/bash", "-c"]
# RUN conda create -n main python=3.11 -y
# SHELL ["/root/miniconda3/bin/conda", "run", "-n", "main", "/bin/bash", "-c"]
# RUN conda init bash

# Make 10 users with UID 1000 to 1009 because we don't know who's using it as of yet.
RUN /bin/bash -c 'for i in {1000..1009}; do adduser --disabled-password --gecos "" --home /home/docker --shell /bin/zsh docker$i && adduser docker$i sudo && adduser docker$i docker1000; done'
RUN echo '%sudo ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers



ENV HOME /home/docker
ENV DOTFILES_PATH $HOME/.config/dotfiles
ADD . $DOTFILES_PATH
RUN chmod 777 /home/docker -R
RUN chown docker1000:docker1000 /home/docker -R

SHELL ["/bin/bash", "-c"]

USER docker1000
ENV ZSH $HOME/.oh-my-zsh
ENV PATH $HOME/.local/bin:$PATH
ENV INSTALL_DIR $HOME/.local

RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
# RUN chmod 755 $ZSH -R

RUN $DOTFILES_PATH/symlink.sh
RUN $DOTFILES_PATH/install-nvim-tmux-locally-linux.sh
RUN $DOTFILES_PATH/wezterm/terminfo.sh

RUN $DOTFILES_PATH/oh-my-zsh/install-installers.sh
ENV PATH $HOME/.cargo/bin:$PATH
RUN $DOTFILES_PATH/oh-my-zsh/apps-local-install.sh

RUN $DOTFILES_PATH/nvim/install-linux.sh



# RUN source activate main
# RUN mkdir /app/
# ADD requirements.txt /app/
# RUN pip --no-cache-dir install -r /app/requirements.txt
# ADD . /app/
# RUN pip --no-cache-dir install -e /app/

ENTRYPOINT ["/bin/bash"]
