---
description: A slow endpoint in an app that runs Peekaboot loads the skill.
tags: [trigger]
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

Our Spring Boot service has Peekaboot on the classpath and runs locally on port 8080. Some
endpoints got slow since yesterday. Which routes are slowest, and where does the time go?
