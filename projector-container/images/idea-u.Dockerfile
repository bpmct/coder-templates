FROM jetbrains/projector-idea-u:latest

USER root

# We need CURL to start the Coder agent
RUN sudo apt-get update && sudo apt-get install -y curl

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Fix permissions problem
RUN chown -R $PROJECTOR_USER_NAME.$PROJECTOR_USER_NAME /home/$PROJECTOR_USER_NAME/.cache

# Install other base dependencied you need here!

USER projector-user
