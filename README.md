# Wagtail ES Atomic Rebuild

Investigations for https://github.com/wagtail/wagtail/issues/6003

Goal: find the conditions under which the bug in Elasticsearch -
https://github.com/elastic/elasticsearch/issues/24644 - impacts
`update_index`.

Hypothesis: this bug existed in ES 5.4 but was reported as fixed in
5.5. Hope to be able to replicate this bug in those ES versions, and
for it to cause `update_index` to fail.

## Approach

Use https://github.com/wagtail/bakerydemo as some sample code. Get the
code, and apply patches to make it use our selected Elasticsearch
image version (in `docker-compose.yaml`) and Elasticsearch config in
`bakerydemo/settings/production.py`. Run `update_index` and see if
errors. Check for the handling of the ES alias bug by interacting with
ES directly.

## Findings

| ES Version | Command             | ES alias bug present | `update_index` failed     |
| ---------- | -------             | -------------------- | ------------------------- |
| 5.3.2      | `./run.sh es5_3_2`  | no                   | no                        |
| 5.4.0      | `./run.sh es5_4_0`  | yes                  | no                        |
| 5.4.2      | `./run.sh es5_4_2`  | yes                  | no                        |
| 5.4.3      | `./run.sh es5_4_3`  | yes                  | no                        |
| 5.5.2      | `./run.sh es5_5_2`  | no                   | no                        |
| 5.6.3      | `./run.sh es5_6_3`  | no                   | no                        |
| 5.6.16     | `./run.sh es5_6_16` | no                   | no                        |

Note: testing, for starters, with latest ES 5.3, all 5.4s available on
Dockerhub, latest 5.5, latest 5.6, as well as 5.6.3 because of
https://github.com/wagtail/wagtail/issues/3985.
