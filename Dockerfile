FROM debian:stretch

MAINTAINER Datadog <package@datadoghq.com>

ARG AGENT_VERSION_ARG=1:5.32.4-1
ARG AGENT_REPO_ARG=http://apt.datad0g.com/
ARG AGENT_REPO_CHANNEL_ARG=stable

ENV DOCKER_DD_AGENT=yes \
    AGENT_VERSION=$AGENT_VERSION_ARG \
    AGENT_REPO=$AGENT_REPO_ARG \
    AGENT_REPO_CHANNEL=$AGENT_REPO_CHANNEL_ARG \
    DD_ETC_ROOT=/etc/dd-agent \
    PATH="/opt/datadog-agent/embedded/bin:/opt/datadog-agent/bin:${PATH}" \
    PYTHONPATH=/opt/datadog-agent/agent \
    DD_CONF_LOG_TO_SYSLOG=no \
    NON_LOCAL_TRAFFIC=yes \
    DD_SUPERVISOR_DELETE_USER=yes \
    DD_CONF_PROCFS_PATH="/host/proc"

# Install the Agent
RUN apt-get update \
 && apt-get install --no-install-recommends -y gnupg dirmngr \
 && echo "deb ${AGENT_REPO} ${AGENT_REPO_CHANNEL} main" > /etc/apt/sources.list.d/datadog.list \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A2923DFF56EDA6E76E55E492D3A80E30382E94DE \
 && apt-get update \
 && apt-get install --no-install-recommends -y datadog-agent="${AGENT_VERSION}" \
 && apt-get install --no-install-recommends -y ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add healthcheck script
COPY probe.sh /probe.sh

# Configure the Agent
# 1. Remove dd-agent user from init.d configuration
# 2. Fix permission on /etc/init.d/datadog-agent
# 3. Make healthcheck script executable
RUN mv ${DD_ETC_ROOT}/datadog.conf.example ${DD_ETC_ROOT}/datadog.conf \
 && sed -i 's/AGENTUSER="dd-agent"/AGENTUSER="root"/g' /etc/init.d/datadog-agent \
 && chmod +x /etc/init.d/datadog-agent \
 && chmod +x /probe.sh

# Add Docker check
COPY conf.d/docker_daemon.yaml ${DD_ETC_ROOT}/conf.d/docker_daemon.yaml
# Add install and config files
COPY entrypoint.sh /entrypoint.sh
COPY config_builder.py /config_builder.py

# Extra conf.d and checks.d
VOLUME ["/conf.d", "/checks.d"]

# Expose DogStatsD and trace-agent ports
EXPOSE 8125/udp 8126/tcp

# Healthcheck
HEALTHCHECK --interval=5m --timeout=3s --retries=1 \
  CMD ./probe.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["supervisord", "-n", "-c", "/etc/dd-agent/supervisor.conf"]
