# Project 07 Demo Application

A small local HTTP application used to safely test the Application Watchdog.

## Health Endpoint

http://127.0.0.1:8080/health

Expected healthy response:

HTTP 200 OK
OK

The application listens only on 127.0.0.1 and is not exposed externally.

The watchdog uses this application to test health checks, failure detection, evidence collection, controlled recovery, recovery verification, retry/backoff, and escalation.
