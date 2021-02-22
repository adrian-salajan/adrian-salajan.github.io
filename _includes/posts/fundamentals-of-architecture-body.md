# Fundamentals

architecture = structure + characteristics(-illities) + decisions +
design principles Structure = type of architecture -illities =
availability, reliability, testability, scalability, security,
elasticity, fault tolerance, performance, deployability, agility
decisions = the rules for building the system design principles =
guidelines

## Expectations of an architect

-   make architecture decisions
-   continually analyze the architeture
-   ensure compliance
-   posses interpersonal skills
-   have domain knowledge
-   understand company politics
-   keep up to date with latest trends

## Laws of software architecture

1.  Everything in software is a trade-off. If you think a solution does
    not have a trade-off most likely you didn\'t find it yet.
2.  Why is more important than how. An architecutre diagram may explain
    how a system works but not why it was built like that.
3.  There are no right or wrong solutions, only trade-offs.

## Measuring modularity

### Cohesion

-   measures how related parts are with each other

Types of cohesion, best to worst:

1.  functional - everything from one module is needed by another
2.  sequential - one module\'s output is another\'s input
3.  communicational - each module contributes it\'s part to a larger
    output
4.  procedural - modules have to execute code in a particular order
5.  temporal
6.  operations are related but different, e.g.: StringUtils
7.  coincidental - code is in the same module but not related

## Architecture characteristics

A characteristic:

1.  specifies non-domain consideration
2.  influences structure
3.  is important to the systems success

A system cannot have all the characteristics, it is important to
initally choose the most important ones and add other in iterations. A
good architecture is actually a least worse architecture for the given
requirements

### Operational characteristics

-   availability
-   continuity - disaster recovery
-   performance
-   recoverability - how fast recovery is done
-   reliability/safety - needs to be fail-safe, is it mission critical?
-   robustness - handles errors and boundary conditions: bad input, bad
    connection, hardware failure
-   scalability - keep up with increasing requests/users

### Structural characteristics

-   configurability
-   extensibility
-   instabilitty
-   reuse
-   localization/i18n
-   portability
-   supportability - how is it ease to identify errors, e.g: logging,
    debug capabilities
-   upgradeability - easy upgrade versions

### Cross-cutting characteristics

-   accesibility - for users
-   archivability
-   authentification
-   authorization - access to only certain functions of the system
-   legal - data protection, gdpr, audis
-   privacy - hide transactions from people developing/debugging the
    system
-   security - encryption
-   usability

# DDD

Modeling technique splitting complex problems in smaller ones. Bounded
Context - an isolated part of the application, exposing a clear model
and API, hiding the details. Inside it keeps details only relevant to
its responsibility ! creating universal shared models introduces
coupling, the model needing to hold all possible details for it\'s
usecases and so leaks details of one responsibilty into other ones.

in TDD each model is owned by a single BD, the model can have only
relevant details in other BD where used, transormation is done between
same conceptual models in different BD at integration points (ports).

# Component thinking

Components = physical manifestation of modules

-   form the modular building blocks in architecture

-   before identifying components decide how to partition the
    architecture

    -   technical (layered) vs domain partitioning - DDD

## Initial steps:

1.  Identify initial components
2.  Assign requirements to components
3.  Analyze roles and responsibilities (correct granularity)
4.  Analyze architecture characteristics
5.  Restructure components

## Component Design

Avoid the entity trap anti-pattern, where there is a \"Manager\"
components for each entity.

### Actor/Actions

-   identifies actors and what actions they perform
-   good for monolith or distributed

### Event storming

-   assumes event message passing
-   good for distributed/microservices
-   discover what events occur in the system and how are they handled

### Workflows

-   models workflows, like ES, but not assumtion of events passing
-   identifies roles, flows and components to handle them

After initial component design check how architecture characteristics
need to change it.

Architecture quantas can have different characteristics One quanta = one
set of architecture caracteristics = monolith

# Architecture styles

-   overarching structure of organization of UI, backendend, db

## Fallacies of distributed computing

1.  The network is reliable
    -   add timeouts and circuit brackers
2.  Latency is zero
    -   know average latency roundtring in your network
    -   know the 95+th percentiles latencies
3.  Bandwithd is infinite
    minimize data with:
-   private RESTful API
-   use field selectors
-   GraphQL
-   internal message endpoints

4.  The network is secure
    -   secure all endpoints
5.  The network topology never changes
6.  There is only one network admin
7.  Transport cost is \$0
8.  Network is homogeneous

## Other difficulties in distributed software

1.  Distributed logging
2.  Distributed transactions
    -   transactional sagas managed with event sourcing for compensation or
        state machines to manage state of tx
    -   BASE tx: BAsic availability, Soft state, Eventual consistency

1.  Contract maintainance and versioning

## Layered architecture

-   closed layer - requests must not skip this layer and instead must go
    through it. Good isolation, flexible change.
-   open layer - requests can skip this layer and go to the one below.
    Performance benefit

## Pipelines (pipes and filters)

## Micro-kernel

-   good for product software in a single package
-   plugin support
-   core system can be technicaly or domain partitioned
-   ui can be both separate or integrated deployment unit
-   core has main db access, plugins can have their own separate db

## Service based

-   hybrid of microservices architecture
-   considered most pragmatic due to flexibility
-   few coarse-grained services: 4 to 12
-   services share the same db
-   due to shared db, need to avoid inter-services calls =\> fault
    tolerance (if one service fails the others are not impacted)
-   optional API layer (reverse proxy or gateway)
-   API facade for each service

### DB Partitioning

A single shared db can impact all services when it changes. To avoid
this partition the db into domains which are reflected into individual
libs for accessing the db. Every service only uses the db-libs it needs
=\> db changes on one domain are propagated only to those services using
the db-lib for the updated domain

## Event-Driven

-   good fit where there is not a need for classic request-response
-   classing request-response modeled async with events

### Broker topology

Messages/events are published to the broker, interested Event Processors
subscribe for the event, process it and publish back another event.

  |Good    |          Bad|
  ----------------- | --------------------
  decoupling         | workflow control
  scalable           | error handling
  responsive         | recoverability
  performance        | restart
  fault tolerance    | data inconsistency

### Mediator topology

-   mediator which controls the workflow:
    -   simple: apache camel, mule esbp, spring integration
    -   complex (or with manual intervention): apache ode, oracle BPEL
        (xml), BPM engine
    -   starting point should be a simple mediator that can delegate
        complex events to a complex mediator

-   one mediator per domain/group of events

-   mediator know about the workflow, keeps state, can manage error
    handling, recoverability and restarts

-   mediator can be a bottleneck

      |Good                      |Bad|
      ------------------------- |  -----------------------------------
      workflow control           | more coupling of event processors
      error handling             | lower scalability
      recoverability             | lower performance
      restart capabilities       | lower fault tolerance
      better data consistency    | model complex workflows

### Error handling

-   async communication makes error handling harder

## Space based

-   high scalability, elasticity and performance
-   needed in businesses with high spikes of users/request: concert
    ticketing, online auctions
-   processing units keep data in memory & replicated for fast access
-   data grid & data replication: Hazelcast, Apache Ignite, Oracle
    Coherence
-   on data update, async update the persistent db

### Virtualized middleware

1.  Messaging grid
    -   forwards requests to PU
    -   Keeps track of PU and requests
    -   usually web server with load balancing capabilities

2.  Data grid
    -   replicated cache, sync (usually) or async
    -   in the PU and also external of PU for distributed caches

3.  Processing grid
    -   optional: coordinates different PU to handle a complex flow
4.  Deployment manager
    -   monitors and starts/stops PU based on load

### Data pumps

-   send data to another processor which will update the db
-   usually implemented as persistent queues
-   contracts: JSON, XML, objects

### Data writers

-   receives events from data pump and updates db
-   granularity can vary

### Data readers

-   get the data into the PU: on start, after crash, archived data via a
    reverse data pump

## Microservices

### On sizing

Architects make the error of taking \"micro\" as a command not a
description, and they make to small/fine grained services. Avoid the
entity trap - one MS per entity.

When considering size, adapt to:

1.  Purpose/domain Service should be cohesive and solve a business
    requirement
2.  Transactions Distributed transactions are very hard to manage - can
    make the service bigger to avoid distributed tx
3.  Choreography To much inter-service communication - can avoid if
    making the service bigger

-   can have a \"local\" mediator microservice when orchestration in
    needed for complex procceses and better error handling
-   Don\'t do distributed transactions - increase granularity


# Techniques and soft skills

## Decisions

-   gather info, justify decision, document decision, communicate to
    stakeholders

### Antipatterns

-   Covering yout Assets - fear of decision taking
-   Groundhog day - unjustified decision which continually generates
    discussions -\> justify with both technical and business
    perspectives
-   E-mail driven architecture

### Architecturally significant

-   structure / data sharing
-   decisions impacting nonfunctional characteristics
-   dependencies between component and services
-   interfaces: api, service bus, gateway; contracts, versioning
-   construction techniques: platforms, framework, tools, technologies

### ADR Architecture design record

Title, Status, Context, Decision, Consequences, Compliance, Notes

## Architecture risk

-   impact matrix impact/likelyhood
-   risk storming a select area: perf, scalability, technology, security

## Making teams effective

-   control adjustemnts: team familiarity, team size, experience,
    project complexity, project duration

### Team warning signs

-   Process loss (e.g.: merge conflicts) - team too big
-   Pluralistic ignorance: when one agrees with the group but privately
    holds a different opinion. Architect should explicly question/ask
    for members opinion
-   Diffusion of responsability

### Use checklists

-   for workflows which are not sequential

## Negotiation and leadership skills

-   understand what the person using the buzzwords wants to really
    achieve
-   be informed before starting a negotiation
-   put things in cost and time perspective (last resort)
-   use divide and conquer: maybe the system does not need 99.999%
    availability, only a portion of it
    -   demonstration defeats discussion
-   provide justification to developers
-   when developers disagree on a solution, have them reach it on their
    own: ask for solutions/analysis to the problem from the developers

### Architect as a leader

-   50% of being a architect is about people, facilitation and
    leadership skills
-   Every problem is also a people problem.
-   use questions instead of statements: Have you thought about using a
    cache? Vs. We must use a cache.
-   use people\'s names in conversation
-   turn a request into asking for a favor

4Cs of architecture

-   Communication
-   Collaboration
-   Clarity
-   Conciseness

## Architect career path

-   breadth is more important than depth for an architect
-   20 Minutes Rule: InfoQ, DZone Refcards, ThoughtWorks Technology
    Radar
-   use/developer a technology radar

### Personal radar

-   Removes the technology lock-in of the employer

1.  Hold: avoid and stop doing
2.  Assess: promising technologies
3.  Trial: experiments in larger code base, undestand trade-off
4.  Adopt: best practices, things most excited about
