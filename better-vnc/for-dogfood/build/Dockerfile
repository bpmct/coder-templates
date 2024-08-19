FROM kasmweb/desktop:1.12.0

USER root

COPY kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml
COPY vnc_startup.sh /dockerstartup/vnc_startup.sh
RUN cp -r /home/kasm-user /tmp/kasm-user
RUN apt-get update && apt-get install sudo
RUN echo "kasm-user ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/nopasswd
RUN DEBIAN_FRONTEND=noninteractive make-ssl-cert generate-default-snakeoil --force-overwrite
RUN adduser kasm-user ssl-cert

# By default, the kasm web client html page connects to `/websockify` for the websocket connection.
# This fails for path based apps, as we need to prepend the application path.
# Replace the line that sets the websocket path to include the application path.
# Kasm web should only be hosted on the path "/", but just incase it is moved, this regex match
# will only replace the websocket path if the path is in the format of "/@<username>/<appname>/apps/<appname>/"
RUN sed "s#'websockify'#(window.location.pathname.match(/@[^\\\\/]+\\\\/[^\\\\/]+\\\\/apps\\\\/[^\\\\/]+/) ?? [''])[0]+'/websockify'#g" < $KASM_VNC_PATH/www/dist/main.bundle.js > $KASM_VNC_PATH/www/dist/main.bundle.js.tmp
RUN mv $KASM_VNC_PATH/www/dist/main.bundle.js.tmp $KASM_VNC_PATH/www/dist/main.bundle.js

USER 1000