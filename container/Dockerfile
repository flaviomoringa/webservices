#########################################################################
# Node 12 default image - Alpine based
#########################################################################

FROM node:12.13-alpine AS node-compiler
ENV NPM_CONFIG_LOGLEVEL info
ENV ENVIRONMENT production_docker

#########################################################################
# Extra needed packages (nginx + supervisor + git + tzdata (just because
# www servers are not in UTC))
#########################################################################

#RUN apk add --no-cache git g++ make openssh tzdata
RUN apk add --no-cache git g++ make openssh

#########################################################################
# Variable to invalidate cache
#########################################################################

ARG CACHE_DATE=1970-01-01

#########################################################################
# Clone the project and Production configs
#########################################################################

RUN mkdir -p /root/.ssh \
   && ssh-keyscan github.com > /root/.ssh/known_hosts
ADD builder-ssh-key /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa \
    && git clone git@github.com:flaviomoringa/webservices.git /srv/webservices \
    && git clone git@github.com:flaviomoringa/production.git /srv/production
RUN rm -rf /root/.ssh

#########################################################################
# Setup for git-crypt
#########################################################################

RUN apk --no-cache add ca-certificates gnupg \
   && wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-git-crypt/master/sgerrand.rsa.pub \
   && wget https://github.com/sgerrand/alpine-pkg-git-crypt/releases/download/0.6.0-r1/git-crypt-0.6.0-r1.apk \
   && apk add git-crypt-0.6.0-r1.apk

#########################################################################
# unlock with git-crypt
#########################################################################

ADD builder-gpg-key /tmp/builder-gpg-key
RUN gpg --import /tmp/builder-gpg-key \
    && cd /srv/production \
    && git-crypt unlock

#########################################################################
# set working directory
#########################################################################

WORKDIR /srv/webservices

#########################################################################
# Code Build
#########################################################################

# Because this repo also had git-crypt, and so that it does
# not fail the node compilation
RUN git-crypt unlock

RUN rm -rf ./node_modules \
    && npm install \
    && npm run build

#########################################################################
# nodejs-base image - Final image
#########################################################################

FROM XXXXXXXXXXXX.dkr.ecr.eu-west-1.amazonaws.com/base/nodejs:12.13

#########################################################################
# set working directory
#########################################################################

WORKDIR /srv/webservices
COPY --from=node-compiler /srv/webservices /srv/webservices/.
COPY --from=node-compiler /srv/production /srv/production/.


#########################################################################
# Change data to CEST - Otherwise it stays in UTC and JWT fails
# REMOVE after changing frontends to UTC as they should (also remove
# the tzdata installation package above)
#########################################################################

#COPY --from=node-compiler /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
#RUN echo "Europe/Amsterdam" > /etc/timezone


#########################################################################
# Install sequelize
#########################################################################

# To handle 'not get uid/gid'
RUN npm config set unsafe-perm true

RUN npm install -g sequelize-cli

#########################################################################
# Copy configs to code path
#########################################################################

RUN cp -av /srv/production/repositories/backend/files/* /srv/webservices \
    && rm -rf /srv/production/ \
    && rm -f /srv/webservices/src/config/.gitattributes

#########################################################################
# Fluentd conf
#########################################################################

ADD ./conf/fluentd_webservices.conf /etc/fluent/fluent.conf

#########################################################################
# Supervisor Confs
#########################################################################

ADD ./conf/nginx.conf /etc/supervisor/conf.d/nginx.conf
ADD ./conf/node.conf /etc/supervisor/conf.d/node.conf
ADD ./conf/fluentd.conf /etc/supervisor/conf.d/fluentd.conf

#########################################################################
# Nginx - Sites and Configs
#########################################################################

#Remove current access_log directive if it exists
RUN sed -i '/access_log/d' /etc/nginx/nginx.conf
RUN sed -i '/log_format/d' /etc/nginx/nginx.conf

#use our log_format where we use the x-forward-for as remote address
COPY ./conf/nginx_log.conf /etc/nginx/conf.d/nginx_log.conf

ADD ./conf/webservices.conf /etc/nginx/sites-enabled/webservices.conf
ADD ./conf/deny.conf /etc/nginx/deny.conf
RUN chown -R nginx. /srv/webservices

#########################################################################
# Test suit copy
#########################################################################

ADD ./tests/all.sh /all.sh

#########################################################################
# Entrypoint copy
#########################################################################

ADD ./conf/docker-start /docker-start
RUN chmod +x /docker-start

#########################################################################
# Boot
#########################################################################

EXPOSE 80

CMD ["/docker-start"]
