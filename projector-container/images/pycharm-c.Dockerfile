FROM jetbrains/projector-pycharm-c:latest

USER root

# We need CURL to start the Coder agent
RUN sudo apt-get update && sudo apt-get install -y curl

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install other base dependencied you need here!

USER projector-user
