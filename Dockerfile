FROM ubuntu:24.04
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
		vim-gtk3 \
		tzdata \
		libgl1 \
		sudo \
		locales \
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

# Make 20 users with UID 1000 to 1020 because we don't know who's using it as of yet.
RUN for i in {1000..1020}; do adduser --disabled-password --gecos "" --home /home/docker --shell /bin/zsh docker$i \
    && adduser docker$i sudo && adduser docker$i docker1000 \
	&& echo "docker$i ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; done

RUN adduser --disabled-password --gecos "" linuxbrew
RUN echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN for i in {1000..1020}; do adduser docker$i linuxbrew; done
USER linuxbrew
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

ENV PATH $PATH:/home/linuxbrew/.linuxbrew/bin
RUN echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/linuxbrew/.profile
ENV HOMEBREW_NO_AUTO_UPDATE=1

RUN brew install zsh && brew cleanup
RUN sudo ln -s /home/linuxbrew/.linuxbrew/bin/zsh /bin

RUN sudo chmod 777 /home/docker -R
RUN sudo chown docker1000:docker1000 /home/docker -R

USER docker1000
ENV HOME /home/docker
ENV DOTFILES_PATH $HOME/.config/dotfiles
ENV ZSH $HOME/.oh-my-zsh
ENV PATH $HOME/.cargo/bin:$HOME/.local/bin:$HOME/.pixi/bin:$PATH:/home/linuxbrew/.linuxbrew/bin
ENV LD_LIBRARY_PATH $HOME/.local/lib:$LD_LIBRARY_PATH:/home/linuxbrew/.linuxbrew/lib
ENV INSTALL_DIR $HOME/.local

RUN mkdir -p "$HOME/bin"
RUN wget "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" -P "$HOME/bin" \
	&& bash "$HOME/bin/Miniforge3-$(uname)-$(uname -m).sh" -b -p "$HOME/bin/miniforge3" \ 
	&& rm "$HOME/bin/Miniforge3-$(uname)-$(uname -m).sh"
RUN chmod 777 $HOME/bin -R
# SHELL ["$HOME/bin/miniforge3/bin/conda", "run", "-n", "base", "/bin/bash", "-c"]
# RUN conda create -n main python=3.11 -y
# SHELL ["$HOME/bin/miniforge3/bin/conda", "run", "-n", "main", "/bin/bash", "-c"]
# RUN conda init bash

# Rust/Cargo are managed directly by rustup, not apt or mise.
RUN set -o pipefail \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable

# Use the same global CLI versions as macOS/Linux hosts, without mise shims.
# Each RUN has a fresh shell: activate direct tool paths with mise env before
# using managed commands. Interactive Zsh uses mise activate from .zshrc.
COPY --chown=docker1000:docker1000 ./mise-config/config.toml ./mise-config/mise.lock $HOME/.config/mise/
RUN curl -fsSL https://mise.run | sh \
    && mise install --locked --jobs 2 \
    && mise run install-extras

# Neovim dependencies
# RUN pip3 install --user virtualenvwrapper
# RUN pip3 install --user debugpy
# RUN pip3 install --user pynvim jupyter_client cairosvg plotly kaleido pnglatex pyperclip
# RUN npm install -g neovim
COPY --chown=docker1000:docker1000 ./nvim/install-dependencies.sh $HOME
RUN eval "$(mise env -s bash)" \
    && $HOME/install-dependencies.sh
RUN rm $HOME/install-dependencies.sh

# NOTE: All of the files COPY-ed now are for installation only. They will be replaced later with mise dotfile links.
COPY --chown=docker1000:docker1000 ./tmux/.tmux.conf $HOME
RUN eval "$(mise env -s bash)" \
    && git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm \
    && tmux start-server \
    && tmux new-session -d \
	&& ~/.tmux/plugins/tpm/scripts/install_plugins.sh \
    && chmod 777 $HOME/.tmux -R

RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
RUN chmod 755 $ZSH -R
RUN sudo chown root:root /home/docker/.oh-my-zsh -R

RUN tempfile=$(mktemp) \
	&& curl -o $tempfile https://raw.githubusercontent.com/wez/wezterm/master/termwiz/data/wezterm.terminfo \
	&& tic -x -o ~/.local/share/terminfo $tempfile \
	&& tic -x -o ~/.terminfo $tempfile \
	&& rm $tempfile \
	&& chmod 777 $HOME/.terminfo -R

COPY --chown=docker1000:docker1000 ./nvim $HOME/.config/nvim
RUN eval "$(mise env -s bash)" \
    && nvim +"lua require('lazy').restore({wait=true})" +qa
RUN eval "$(mise env -s bash)" \
    && nvim -u $DOTFILES_PATH/nvim/treemux_init.lua +"lua require('lazy').restore({wait=true})" +qa
# RUN nvim a.py +"CocInstall -sync coc-pyright" +qa
RUN eval "$(mise env -s bash)" \
    && nvim a.py +TSUpdateSync +qa

COPY --chown=docker1000:docker1000 ./ranger $DOTFILES_PATH/ranger
COPY --chown=docker1000:docker1000 ./nvim-coc $DOTFILES_PATH/nvim-coc
COPY --chown=docker1000:docker1000 ./nvim-lazyvim $DOTFILES_PATH/nvim-lazyvim
COPY --chown=docker1000:docker1000 ./helix $DOTFILES_PATH/helix
COPY --chown=docker1000:docker1000 ./conda $DOTFILES_PATH/conda
COPY --chown=docker1000:docker1000 ./cargo $DOTFILES_PATH/cargo
COPY --chown=docker1000:docker1000 ./mise-config $DOTFILES_PATH/mise-config
COPY --chown=docker1000:docker1000 ./wezterm $DOTFILES_PATH/wezterm
COPY --chown=docker1000:docker1000 ./mise.toml $DOTFILES_PATH/mise.toml
COPY --chown=docker1000:docker1000 ./kitty $DOTFILES_PATH/kitty
COPY --chown=docker1000:docker1000 ./dprint $DOTFILES_PATH/dprint
COPY --chown=docker1000:docker1000 ./autokey/data $DOTFILES_PATH/autokey/data
COPY --chown=docker1000:docker1000 ./nvim $DOTFILES_PATH/nvim
COPY --chown=docker1000:docker1000 ./tmux $DOTFILES_PATH/tmux
COPY --chown=docker1000:docker1000 ./oh-my-zsh $DOTFILES_PATH/oh-my-zsh
RUN chmod 777 $HOME/.config -R

RUN mise trust $DOTFILES_PATH/mise.toml \
    && mise -C "$DOTFILES_PATH" bootstrap dotfiles apply --force --yes

RUN eval "$(mise env -s bash)" \
    && zoxide add $HOME/.config \
    && zoxide add $HOME/.local/share/nvim \
	&& zoxide add $HOME/.local/share/nvim/lazy \
	&& zoxide add $HOME/.config/dotfiles \
	&& zoxide add $HOME/.config/dotfiles/nvim \
	&& zoxide add $HOME/.config/dotfiles/nvim/lua/kiyoon \
	&& zoxide add $HOME/.config/dotfiles/tmux \
	&& zoxide add $HOME/.config/dotfiles/oh-my-zsh \
	&& zoxide add $HOME/.config/dotfiles/oh-my-zsh/custom/plugins

RUN chmod 777 $HOME/.local -R
RUN chmod 777 $HOME/.conda -R
RUN chmod 777 $HOME/.cache -R
RUN chmod 777 $HOME/.config -R
RUN chmod 777 $HOME/.cargo -R
RUN chmod 777 $HOME/.npm -R
# RUN sudo chmod 755 /home/linuxbrew -R

# RUN source activate main
# RUN mkdir /app/
# COPY requirements.txt /app/
# RUN pip --no-cache-dir install -r /app/requirements.txt
# COPY . /app/
# RUN pip --no-cache-dir install -e /app/

WORKDIR /home/docker
ENTRYPOINT ["/bin/zsh"]
