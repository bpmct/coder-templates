FROM jupyter/base-notebook

USER root

# install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh


