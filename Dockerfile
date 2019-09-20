FROM ruby:2.5

# The locale must be UTF-8 for the json fixtures
# to be interpreted correctly by ruby
ENV LANG C.UTF-8

RUN wget https://github.com/Yelp/dumb-init/releases/download/v1.0.0/dumb-init_1.0.0_amd64.deb \
 && dpkg -i dumb-init_*.deb \
 && rm *.deb

RUN mkdir /app
WORKDIR /app

COPY [ "./Gemfile", "/app/" ]
COPY [ "./Gemfile.lock", "/app/" ]
RUN bundle install

# Install aescrypt for sourcing secrets
RUN apt-get update                                                 \
 && apt-get install -y unzip vim awscli                            \
 && apt-get clean                                                  \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN cd /root/                                                      \
 && wget https://github.com/FreedomBen/aescrypt/archive/master.zip \
 && unzip master.zip                                               \
 && cd aescrypt-master/linux/src                                   \
 && make                                                           \
 && make install                                                   \
 && cd /root                                                       \
 && rm -rf aescrypt-master master.zip

COPY . /app
# For some reason we are missing gems at this point
# RUN bundle install

RUN mkdir /home/docker              \
  && useradd -d /home/docker docker \
  && chown -R docker:docker /home/docker /app /usr/local/bundle

ENV PATH /usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
USER docker

RUN echo 'alias start=/app/scripts/start-bots.sh' >> /home/docker/.bashrc
RUN echo 'alias edit="vim /usr/local/bundle/gems/slackbot_frd-0.3.3/lib/slackbot_frd/lib/slack_connection.rb"' >> /home/docker/.bashrc

CMD [ "dumb-init", "slackbot-frd", "start" ]
