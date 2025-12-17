# Homelab Admin Repository Checklist

This document tracks the current state of the homelab-admin repository and lists improvements needed to make it production-ready.

## ✅ Completed

- [x] **Repository Structure**: Well-organized platform directory with service-specific subdirectories
- [x] **Documentation**: Comprehensive README.md with architecture diagrams and workflows
- [x] **Security Practices**: `.gitignore` properly excludes secrets, keys, and sensitive data
- [x] **nginx Reverse Proxy**: Configured with TLS termination and forward authentication
- [x] **Authentik SSO**: Identity provider configured with server, worker, and outpost components
- [x] **Shared Services**: PostgreSQL and Redis containers for data services
- [x] **Docker Networking**: All services use the `geek-infra` external network
- [x] **nginx Management**: Makefile targets for testing, reloading, and deploying nginx configuration
- [x] **Config Sync**: Bidirectional sync scripts (repo → host for normal workflow, host → repo for emergencies)
- [x] **Authentik Upgrade**: Migrated to version 2025.10.3 with Redis dependency removed

## 🔄 In Progress

- [ ] **Authentik Deployment**: Need to deploy upgraded authentik to production (geek host)

## 📋 Planned / Todo

### High Priority

- [x] **Environment Variable Management**: Create `.env.example` files for all services that need environment variables
  - [x] Authentik: `.env.example` created with `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_POSTGRESQL__PASSWORD`, and `AUTHENTIK_OUTPOST_TOKEN`
  - [ ] PostgreSQL: Document password configuration and authentik user setup
  - [ ] Other services as needed

- [ ] **Database Initialization**: Document or automate PostgreSQL database creation for authentik
  - [ ] Create `authentik` database
  - [ ] Set up proper user permissions
  - [ ] Migration scripts if needed

- [ ] **TLS Certificate Management**: Document certificate renewal and management process
  - [ ] Certificate expiration monitoring
  - [ ] Renewal procedures (Let's Encrypt or other CA)
  - [ ] Deployment process for new certificates

- [ ] **Backup Strategy**: Implement and document backup procedures
  - [ ] PostgreSQL automated backups
  - [ ] Authentik configuration backups
  - [ ] nginx configuration backups (already in git)
  - [ ] Backup retention policy
  - [ ] Restore testing procedures

### Medium Priority

- [ ] **Monitoring & Alerting**: Set up basic monitoring
  - [ ] Container health checks
  - [ ] Service availability monitoring
  - [ ] Log aggregation
  - [ ] Alert notifications (email/Slack/etc.)

- [ ] **CI/CD Pipeline**: Automate deployment and validation
  - [ ] GitHub Actions for config validation
  - [ ] Automated nginx config testing
  - [ ] Docker Compose validation
  - [ ] Documentation linting

- [ ] **Service Health Checks**: Add health check endpoints to docker-compose files
  - [ ] Authentik health check
  - [ ] PostgreSQL health check
  - [ ] nginx health check

- [ ] **Resource Limits**: Define CPU and memory limits for containers
  - [ ] Prevent resource exhaustion
  - [ ] Optimize for the geek host hardware

- [ ] **Network Security**: Enhance network isolation
  - [ ] Consider separate networks for different service tiers
  - [ ] Firewall rules documentation
  - [ ] Port exposure audit

### Low Priority / Nice to Have

- [ ] **Redis Cleanup**: Since authentik no longer needs Redis (as of 2025.8+)
  - [ ] Evaluate if any other services still need Redis
  - [ ] Remove Redis if no longer needed
  - [ ] Update documentation accordingly

- [ ] **Service Dependencies**: Implement proper startup ordering
  - [ ] Use `depends_on` with health checks
  - [ ] Ensure services start in correct order (postgres → authentik → nginx)

- [ ] **Development Environment**: Create development/testing setup
  - [ ] Docker Compose override for local development
  - [ ] Test data seeding
  - [ ] Local domain resolution (e.g., via `/etc/hosts`)

- [ ] **Documentation Improvements**
  - [ ] Add troubleshooting playbooks for common issues
  - [ ] Create network diagram
  - [ ] Document disaster recovery procedures
  - [ ] Add runbooks for common operational tasks

- [ ] **Code Quality**
  - [ ] Shell script linting (shellcheck)
  - [ ] YAML validation
  - [ ] Markdown linting

- [ ] **Observability**
  - [ ] Structured logging configuration
  - [ ] Log retention policies
  - [ ] Metrics collection (Prometheus?)
  - [ ] Distributed tracing (if needed)

- [ ] **High Availability** (future consideration)
  - [ ] PostgreSQL replication
  - [ ] Load balancing for multi-instance services
  - [ ] Failover procedures

- [ ] **Additional Services Integration**
  - [ ] Document how to add new services
  - [ ] Template docker-compose.yml
  - [ ] Template nginx config with forward auth

- [ ] **Secrets Management** (advanced)
  - [ ] Consider Docker Secrets or HashiCorp Vault
  - [ ] Automated secret rotation
  - [ ] Secret encryption at rest

## 🎯 Current Focus

**Authentik Upgrade to 2025.10.3**: Migrating from Redis-dependent version to PostgreSQL-only architecture.

- Upgraded to version 2025.10.3
- Removed Redis environment variables from authentik configuration
- Redis container can be evaluated for removal if no other services use it
- Need to deploy changes to production

## 📝 Notes

- This checklist is a living document and should be updated as the repository evolves
- Items can be moved between sections as work progresses
- Priority levels may change based on operational needs
- Check off items as they are completed with a date/commit reference if helpful

## 🔗 References

- [Authentik 2025.8 Release Notes](https://goauthentik.io/docs/releases/2025.8) - Redis removal
- [PostgreSQL Best Practices](https://wiki.postgresql.org/wiki/Don%27t_Do_This)
- [Docker Compose Best Practices](https://docs.docker.com/compose/production/)
