---
description: A failing request in an app that runs Peekaboot loads the skill.
tags: [trigger]
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

My Spring Boot app runs Peekaboot on localhost:8080. GET /orders/42 returns a 500 and the
console shows nothing useful. How do I find out why?
