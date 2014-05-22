FROM dqminh/upstart-dind

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV RUBY_ROOT /usr/local
ENV RUBY_VERSION 2.0.0-p247

RUN apt-get update && apt-get install -yy \
  build-essential \
  curl \
  git-core \
  libcurl4-openssl-dev \
  libxml2 \
  libxml2-dev \
  libxslt1-dev \
  lxc \
  python-dev \
  python-pip \
  python-setuptools \
  s3cmd \
  wget

RUN easy_install \
  jinja2 \
  paramiko \
  yaml

RUN pip install ansible==1.2.2

RUN cd /tmp \
  && wget -O ruby-install-0.4.1.tar.gz https://github.com/postmodern/ruby-install/archive/v0.4.1.tar.gz \
  && tar -xzvf ruby-install-0.4.1.tar.gz \
  && cd ruby-install-0.4.1/ \
  && make install \
  && cd /tmp \
  && rm -rf ruby-install-0.4.1 \
  && rm -rf ruby-install-0.4.1.tar.gz

RUN ruby-install -i /usr/local ruby-2.1.1

WORKDIR /bombay
