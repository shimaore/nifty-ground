#!/bin/sh
chown -R nifty-ground /data
su-exec nifty-ground "$@"
