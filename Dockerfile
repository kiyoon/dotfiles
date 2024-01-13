FROM --platform=linux/amd64 nvidia/cuda:12.1.1-base-ubuntu22.04
LABEL org.opencontainers.image.source="https://github.com/kiyoon/dotfiles"

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
		locales \
		cargo \
		&& \
	apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH /usr/local/cuda/lib64:$LD_LIBRARY_PATH
ENV PATH /usr/local/cuda/bin:$PATH
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Korean support
# RUN localedef -f UTF-8 -i ko_KR ko_KR.UTF-8
# ENV LC_ALL ko_KR.UTF-8
RUN localedef -f UTF-8 -i en_US en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV PYTHONIOENCODING=utf-8

RUN git lfs install

RUN sh -c "$(curl -fsSL https://starship.rs/install.sh)" sh -b "/usr/bin" -y
RUN curl -sL install-node.vercel.app/lts | bash -s -- --prefix=/usr/local -y
# RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
#     && bash Miniconda3-latest-Linux-x86_64.sh -b \
#     && rm Miniconda3-latest-Linux-x86_64.sh
#
# SHELL ["/root/miniconda3/bin/conda", "run", "-n", "base", "/bin/bash", "-c"]
# RUN conda create -n main python=3.11 -y
# SHELL ["/root/miniconda3/bin/conda", "run", "-n", "main", "/bin/bash", "-c"]
# RUN conda init bash

# Make 20 users with UID 1000 to 1020 because we don't know who's using it as of yet.
RUN for i in {1000..1020}; do adduser --disabled-password --gecos "" --home /home/docker --shell /bin/zsh docker$i \
    && adduser docker$i sudo && adduser docker$i docker1000 \
	&& echo "docker$i ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; done

RUN adduser --disabled-password --gecos "" linuxbrew
RUN echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN for i in {1000..1020}; do adduser docker$i linuxbrew; done
USER linuxbrew
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

ENV PATH /home/linuxbrew/.linuxbrew/bin:$PATH
ENV HOMEBREW_NO_AUTO_UPDATE=1

RUN brew install zsh
RUN sudo ln -s /home/linuxbrew/.linuxbrew/bin/zsh /bin
RUN brew install ripgrep exa bat fd zoxide fzf pipx thefuck tig gh jq viu bottom dust procs csvlens helix neovim tmux

ENV HOME /home/docker
ENV DOTFILES_PATH $HOME/.config/dotfiles
ADD . $DOTFILES_PATH
RUN sudo chmod 777 /home/docker -R
RUN sudo chown docker1000:docker1000 /home/docker -R

USER docker1000
ENV ZSH $HOME/.oh-my-zsh
ENV PATH /home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:$PATH
ENV INSTALL_DIR $HOME/.local

RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
RUN chmod 755 $ZSH -R

RUN $DOTFILES_PATH/symlink.sh
RUN $DOTFILES_PATH/wezterm/terminfo.sh

RUN $DOTFILES_PATH/oh-my-zsh/install-installers.sh
ENV PATH $HOME/.cargo/bin:$PATH
# RUN $DOTFILES_PATH/oh-my-zsh/apps-local-install.sh

RUN $DOTFILES_PATH/nvim/install-linux.sh
RUN $DOTFILES_PATH/tmux/install-plugins.sh
RUN nvim +"lua require('lazy').restore({wait=true})" +qa
RUN nvim -u $DOTFILES_PATH/nvim/treemux_init.lua +"lua require('lazy').restore({wait=true})" +qa
RUN nvim a.py +"CocInstall -sync coc-pyright" +qa
RUN nvim a.py +TSUpdateSync +qa

RUN zoxide add /home/docker/.config
RUN zoxide add /home/docker/.local/share/nvim
RUN zoxide add /home/docker/.local/share/nvim/lazy
RUN zoxide add /home/docker/.config/dotfiles
RUN zoxide add /home/docker/.config/dotfiles/nvim
RUN zoxide add /home/docker/.config/dotfiles/nvim/lua/kiyoon
RUN zoxide add /home/docker/.config/dotfiles/tmux
RUN zoxide add /home/docker/.config/dotfiles/oh-my-zsh
RUN zoxide add /home/docker/.config/dotfiles/oh-my-zsh/custom/plugins

RUN chmod 777 /home/docker/.local -R
RUN chmod 777 /home/docker/.conda -R
RUN chmod 777 /home/docker/.cache -R
RUN chmod 777 /home/docker/.config -R
RUN chmod 777 /home/docker/.cargo -R
RUN chmod 777 /home/docker/.npm -R
RUN chmod 777 /home/docker/.terminfo -R
RUN chmod 777 /home/docker/.tmux -R
RUN chmod 777 /home/docker/bin -R
RUN chmod 755 /home/docker/.oh-my-zsh -R
RUN sudo chown root:root /home/docker/.oh-my-zsh -R

# RUN source activate main
# RUN mkdir /app/
# ADD requirements.txt /app/
# RUN pip --no-cache-dir install -r /app/requirements.txt
# ADD . /app/
# RUN pip --no-cache-dir install -e /app/

WORKDIR /home/docker
ENTRYPOINT ["/bin/zsh"]
