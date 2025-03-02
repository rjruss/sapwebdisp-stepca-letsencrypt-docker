# sapwebdisp-stepca-letsencrypt-docker

Provisioning multiple SAP Web Dispatchers in various configurations in Docker containers. </br>
Each config with a different approach to TLS certificates, either issued by Step-CA, Lets Encrypt or Private CAs.

Link to post explaining setup [Docker: SAP Web Dispatcher](https://www.rjruss.info/2025/03/setting-up-sap-web-dispatcher-with-tls.html).

SAP Web Dispatcher - [SAP Web Dispatcher, it is located between the Internet and your SAP system. It is the entry point for HTTP(s) requests into your system, which consists of one or more application servers](https://help.sap.com/docs/ABAP_PLATFORM_NEW/683d6a1797a34730a6e005d1e8de6f22/488fe37933114e6fe10000000a421937.html?locale=en-US) </br>
Step-CA link - [step-ca is an online Certificate Authority (CA) for secure, automated X.509 and SSH certificate management](https://smallstep.com/docs/step-ca/) </br>
Let's Encrypt - [Let’s Encrypt is a free, automated, and open Certificate Authority (CA), run for the public’s benefit. It is a service provided by the Internet Security Research Group (ISRG)](https://letsencrypt.org/) </br>
Encrypting passwords with Age - [age is a simple, modern and secure file encryption tool, format, and Go library](https://github.com/FiloSottile/age)


