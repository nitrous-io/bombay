# Action.io: Nagios Server Monitoring

Action.io uses Nagios as an alert mechanism for checking servers. Nagios checks for the health of each server and sends out notifications when things go wrong.

## How Nagios works

Think of Nagios as a star topology. There is a central Nagios server, and there are many hosts being monitored. The central Nagios server hosts a web interface which shows the status of all the hosts. The monitored hosts installs a NRPE server. Each monitored host installs a set of plugins that checks for system metrics.

The Nagios central server polls each monitored host for their health. When the monitored host receives a request from the Nagios central server, it runs the plugins and reports the results to the central Nagios server.

## How it is set up in Ansible

There are two main plays. There is a play which installs the central Nagios server. And another which installs the NRPE server on the monitored hosts.

The central Nagios server should always be set up before the monitored hosts are set up. This is because the monitored hosts need to know the ip of the central Nagios server. As the central Nagios server is built, its ip information is written to a configuration file at __ansible/config/nagios-server.yml__.

When a monitored host is built, it too writes its ip information to a configuration file at __ansible/config/nagios-host.yml__. The Ansibel play for the monitored host will read the configurations and perform the necessary configurations.
