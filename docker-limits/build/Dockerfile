FROM ubuntu

RUN apt-get update \
	&& apt-get install -y \
	curl \
	git \
	golang \
	sudo \
	vim \
	wget \
	&& rm -rf /var/lib/apt/lists/*

ARG USER=coder
RUN useradd --no-create-home --shell /bin/bash ${USER}

## Use this command to add sudo support
# RUN useradd --groups sudo --no-create-home --shell /bin/bash ${USER} \
	# && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USER} \
	# && chmod 0440 /etc/sudoers.d/${USER}
	
USER ${USER}
WORKDIR /home/${USER}
