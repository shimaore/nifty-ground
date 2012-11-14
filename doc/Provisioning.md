Introduction, Prerequisites
===========================

The following steps are currently not automated and might not be
available in the portal. They must be performed after the steps in
the [[Install]], which documents how to install the packages and
bootstrap the installation on the manager server.

It is important that the manager server be accessible to you via its
hostname (for example by adding a record for it your local `/etc/hosts` file)
because the installation scripts cannot guess how you might access it
(for example via a VPN or SSH port redirection).

Note: Once you will have enabled `ccnq3_dns` and will be using the DNS
services provided by the system you should be able to remove the entry
in your `/etc/hosts` file, assuming you can get to the host using the
information available in public DNS.


Naming conventions in this document
===================================

In this document we will assume that your main domain for installation
is `phone.example.net`. IP Addresses are assigned from a block in RFC5737.

    vm1.phone.example.net  198.51.100.51
    vm2.phone.example.net  198.51.100.52
    vm3.phone.example.net  198.51.100.53

We will use two SIP domains, `a.phone.example.net` for client-side,
and `trunk.phone.example.net` for the carrier-side.

Host `vm1` will be the manager host; host `vm2` will be a client-side server,
and host `vm3` will be a carrier-side server.


Create a managing user
======================

* Register on the web application.

     http://vm1.phone.example.net:8080/

* Password will come via email; make sure nullmailer and the upstream
  MTA are able to forward emails.

  Note: configure the upstream MTA in /etc/nullmailer/remotes if you haven't
        done so during the installation the nullmailer package.

  After you register,
  use "Recover password" until you receive the notification email.

* Log into the web application to confirm it is working.

  Note: login will fail if you attempt to use e.g. an IP address instead of
  the host name. This is why a prerequisite was that the manager be
  accessible through its hostname.

  Note: login will fail if the database is not accessible from your web browser.

* Logout from the web application.

* At the command prompt on the manager server, run

      /usr/sbin/ccnq3 admin <email>

  as root, replacing `<email>` with the email address you registered with.

DNS
===

The following step is to enable the `ccnq3_dns` service, which will provide dedicated
DNS responses based on your provisioning data.

Standard DNS layout
-------------------

We recommend that most hosts use a locally-installed DNS cache resolver (such as the plain bind9
package). Their /etc/resolv.conf file should therefor contain:

    nameserver 127.0.0.1

These hosts will require no further changes related to DNS.

Hosts running the `ccnq3_dns` service
-------------------------------------

Optimally you should select a pair of servers to run the `ccnq3_dns` service. These servers
will not be able to run bind9, so they must rely on (at least two) other servers (preferably
in the CCNQ3 system) to provide them with DNS service. Their /etc/resolv.conf file should
therefor contain the IP addresses for these two (or more) servers.

On these servers you should also install the ccnq3-dns package:

    aptitude install -q -y ccnq3-dns

Domains to be created
---------------------

You must create two records in the provisioning database (using Futon):

* one record for the main domain "phone.example.net"
* one record for the subdomain "enum.phone.example.net"

These records should be layed out as follows:

    {
      "_id":"domain:phone.example.net",
      "type":"domain"
      "domain":"phone.example.net",
      "records":[
        {"class":"NS","value":"vm1.phone.example.net"}
      ]
    }

    {
      "_id":"domain:enum.phone.example.net",
      "type":"domain",
      "domain":"enum.phone.example.net",
      "ttl":60,
      "ENUM":true,
      "records":[
        {"class":"NS","value":"vm1.phone.example.net"}
      ]
    }

Notes:

* Any host with applications/dns running should be listed as NS.
* No account field, so these records won't be picked-up for replication.


Adding a new "voice" host
=========================

* Install the "ccnq3-voice" package on the host.
* Log into the web application and go to Provisioning/New host;
* Add a record for one host, e.g. vm2.phone.example.net
* Enter the appropriate IP addresses, enter a SIP domain (cluster domain).
* Select the proper applications for the host.
* Submit.

* Click on the new record to open it, copy the "bootstrap" command.
* Logout from the portal.

* Go back to the admin login for Futon;
  (make sure you are logged out first -- use the Logout button)

* In the database "provisioning" locate the new host's record and
  modify or add the following fields:

      opensips:
        {
          "model": "complete"
        }
      traces:
        {
          "interfaces": [
            "eth0",
            "eth1"
          ]
        }

* Then log into the host and run:

      cd /opt/ccnq3/src/
      # Use the URL from the provisioning portal (above).
      sudo aptitude install ccnq3-client
      # Just to make sure, restart ccnq3
      sudo /etc/init.d/ccnq3 restart
      # Normally freeswitch and opensips are still not running.
      sudo /etc/init.d/opensips start
      sudo /etc/init.d/freeswitch start

* Currently all FreeSwitch changes can be triggered from CouchDB
  (using the appropriate `sip_commands` if needed) or (which is
  equivalent) from the web portal.

  OpenSIPS configuration changes require a restart of OpenSIPS
  (but there are only a few parameters that would require this).

* Add a registering endpoint record to test the new setup.

   Register Usermame: 0976543210@a.phone.example.net
   Register Password: XXXX
   Account: test
   Location: home
   Outbound Route: 1

* Test registration.

Finishing configuring the hosts
===============================

* Here are example records for the "client-sbc" host and the "carrier-side sbc" host.

  This host is a "client sbc" in cluster "a.phone.example.net".
  `ingress_acl` should contain the IP addresses of the carrier-side SBCs.

      {
        "_id":"host:vm2.phone.example.net",
        "type":"host",
        "host":"vm2.phone.example.net",
        "provisioning": ....,
        "password":"XXXX",
        "interfaces": ....,
        "account":"",
        "mailer":{},
        "applications":["applications/host","applications/freeswitch","applications/opensips","applications/traces"],
        "traces":{"interfaces":["eth0","eth1"]},

        "sip_domain_name":"a.phone.example.net",
        "opensips":{"model":"complete"},
        "sip_profiles":{
          "test":{
            "template":"sbc-nomedia",
            "ingress_sip_ip":"198.51.100.52",
            "ingress_sip_port":5200,
            "ingress_acl":["198.51.100.53/32"],
            "egress_acl":[198.51.100.52/32"],
            "handler":"client-sbc",
            "type":"france",
            "send_call_to":"bridge",
            "ingress_target":"a.phone.example.net",
            "egress_target":"trunk.phone.example.net",
            "egress_gwid":1
          }
        }

      }

  This host is a "carrier-side sbc" in cluster "trunk.phone.example.net".

      {
        "_id":"host:vm3.phone.example.net",
        "type":"host",
        "host":"vm3.phone.example.net",
        "provisioning": ...,
        "password":"XXXX",
        "interfaces": ...,
        "account":"",
        "mailer":{},
        "applications":["applications/host","applications/dns","applications/freeswitch","applications/opensips","applications/traces"],

        "sip_domain_name":"trunk.phone.example.net",
        "opensips":{"model":"outbound-proxy"},
        "sip_profiles":{
          "sotel":{
            "template":"sbc-nomedia",
            "ingress_sip_ip":"198.51.100.53",
            "ingress_sip_port":5200,
            "ingress_acl":["4.53.160.135/32","4.53.160.136/32"],
            "egress_acl":["198.51.100.52/32"],
            "handler":"sotel",
            "send_call_to":"bridge",
            "egress_target":"termination2.sotelips.net",
            "enum_root":"enum.phone.example.net",
            "egress_gwid":100
          }
        }

      }


* To apply the changes:

  Logout of Futon, login to the portal,
  open the host record and select "reload sofia",
  submit, re-open the host record ("No FreeSwitch changes" should be selected)
  and re-submit.

* You'll also need an endpoint to identify the client-sbc with the
  carrier-side proxy.

      {
        "_id":"endpoint:198.51.100.52",
        "type":"endpoint",
        "endpoint":"198.51.100.52",
        "sbc":2,
        "outbound_route":1
      }


* Configure OpenSIPS routing:

  The groupid should match the `outbound_route` for the endpoints.
  The ruleid is a random/incremental field used to manage the records.

  * Add rule records

    Routes from the client-side OpenSIPS to the client-side FreeSwitch.
    Mostly used to allow/deny destinations.

       {
        "_id":"rule:vm2.phone.example.net:1",
        "account":"",
        "type":"rule",
        "host":"vm2.phone.example.net",
        "ruleid":1,

        "groupid":1,
        "prefix":"",
        "timerec":"",
        "priority":1,
        "gwlist":"1",
        "routeid":0,
        "attrs":""
      }

    Routes from the carrier-side OpenSIPS to the carrier-side FreeSwitch.
    Used for LCR routing.

      {
        "_id":"rule:vm3.phone.example.net:1",
        "type":"rule",
        "rule":"vm3.phone.example.net:1",
        "host":"vm3.phone.example.net",
        "ruleid":1,

        "groupid":1,
        "prefix":"",
        "timerec":"",
        "priority":1,
        "gwlist":"100",
        "routeid":0,
        "attrs":""
      }


  * Send `reload routes` command (in the portal)


End-user data
=============

Here are some provisioning records as examples.

Endpoint
--------

See above for a complete example.

Number
------

There are two types of "number" records. Both types must be provisioned for
a number to be fully provisioned.

Unqualified (global) number records are used by the carrier-side SBCs to
know which cluster will handle an incoming number.
These "number" records populate Carrier ENUM for inbound routing and CDR
generation.
The number is expressed in E.164 format without a "+" sign.

    {
      "_id":"number:33976543210",
      "number":"33976543210",
      "type":"number",

      "account":"stephane",
      "inbound_uri":"sip:33976543210@ingress-test.a.phone.example.net"
    }

Qualified (local) number records are used by a client-side SBC to
know which endpoint will handle an incoming number.
They may also contain additional information such as the location of that
specific number (for the purpose of emergency call routing).
Since the default value for OpenSIPS' `number_domain` is `local`, the
name after the @ sign will generally be `local`.

    {
      "_id":"number:0976543210@local",
      "type":"number",
      "number":"0976543210@local",

      "endpoint":"0976543210@a.phone.example.net",
      "location":"maison"
    }


Location
--------

Used for emergency call routing.

    {
        "_id":"location:maison",
        "type":"location",
        "location":"maison",

        "account":"",
        "routing_data":"29789"
    }

Further Reading
===============

This document is meant to help you bootstrap your provisioning.

A complete provisioning documentation is available in [[data-dictionary]].