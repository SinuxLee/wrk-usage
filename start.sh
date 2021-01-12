#!/usr/bin/env bash
wrk -t 4 -c 200 -d 120s --latency -s wrk.lua http://172.29.64.1:8086