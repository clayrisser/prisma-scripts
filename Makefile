# File: /Makefile
# Project: nestjs-axios-logger
# File Created: 23-10-2022 05:07:14
# Author: Risser Labs LLC <info@risserlabs.com>
# -----
# Last Modified: 04-11-2022 06:35:27
# Modified By: Clay Risser
# -----
# Risser Labs LLC (c) Copyright 2021 - 2022
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include mkpm.mk
ifneq (,$(MKPM_READY))
include $(MKPM)/gnu
include $(MKPM)/mkchain
include $(MKPM)/yarn
include $(MKPM)/envcache
include $(MKPM)/dotenv

export BABEL ?= $(call yarn_binary,babel)
export WEBPACK ?= $(call yarn_binary,webpack)
export BROWSERSLIST_BINARY ?= $(call yarn_binary,browserslist)
export CLOC ?= cloc
export CSPELL ?= $(call yarn_binary,cspell)
export ESLINT ?= $(call yarn_binary,eslint)
export JEST ?= $(call yarn_binary,jest)
export PRETTIER ?= $(call yarn_binary,prettier)
export TSC ?= $(call yarn_binary,tsc)

export NPM_AUTH_TOKEN ?= $(shell $(CAT) $(HOME)/.docker/config.json 2>$(NULL) | \
	$(JQ) -r '.auths["registry.gitlab.com"].auth' | $(BASE64_NOWRAP) -d | $(CUT) -d':' -f2)

ACTIONS += install
$(ACTION)/install: package.json
	@$(YARN) install $(ARGS)
	@$(call done,install)

ACTIONS += format~install ##
$(ACTION)/format: $(call git_deps,\.((json)|(md)|([jt]sx?))$$)
	-@$(call prettier,$?,$(ARGS))
	@$(call done,format)

ACTIONS += spellcheck~format ##
$(ACTION)/spellcheck: $(call git_deps,\.(md)$$)
	-@$(call cspell,$?,$(ARGS))
	@$(call done,spellcheck)

ACTIONS += lint~spellcheck ##
$(ACTION)/lint: $(call git_deps,\.([jt]sx?)$$)
	-@$(call eslint,$?,$(ARGS))
	@$(call done,lint)

ACTIONS += test~lint ##
$(ACTION)/test: $(call git_deps,\.([jt]sx?)$$)
	-@$(MKDIR) -p node_modules/.tmp
	-@$(call jest,$?,$(ARGS))
	@$(call done,test)

ACTIONS += build~test ##
BUILD_TARGET := lib/index.js
lib/index.js:
	@$(call reset,build)
$(ACTION)/build: $(call git_deps,\.([jt]sx?)$$)
	@$(WEBPACK)
	@$(BABEL) --env-name esm src -d lib --extensions '.js,.jsx,.ts,.tsx' --source-maps
	@$(ECHO) '{"type": "module"}' > lib/package.json
	@$(TSC) -p tsconfig.build.json -d
	@$(call done,build)

COLLECT_COVERAGE_FROM := ["src/**/*.{js,jsx,ts,tsx}"]
.PHONY: coverage +coverage
coverage: | ~lint +coverage
+coverage:
	@$(JEST) --coverage --collectCoverageFrom='$(COLLECT_COVERAGE_FROM)' $(ARGS)

.PHONY: prepare
prepare: ;

.PHONY: browserslist
browserslist:
	@$(BROWSERSLIST_BINARY)

.PHONY: upgrade
upgrade:
	@$(YARN) upgrade-interactive

.PHONY: inc
inc:
	@$(NPM) version patch --git=false $(NOFAIL)

.PHONY: count
count:
	@$(CLOC) $(shell $(GIT) ls-files)

.PHONY: get-misspelled
get-misspelled:
	@$(MAKE) +lint | $(GREP) -oE 'You have a misspelled word: [^ ]+' | \
		$(SED) 's|.\+: ||g' | $(TR) '[:upper:]' '[:lower:]' | \
		$(SORT) | $(UNIQ) | $(SED) 's|\(.*\)|"\1",|g'

.PHONY: publish +publish
publish: | ~build +publish ##
+publish:
	@$(NPM) publish --access=public

.PHONY: clean
clean: ##
	-@$(MKCACHE_CLEAN)
	-@$(JEST) --clearCache $(NOFAIL)
	-@$(GIT) clean -fXd \
		$(MKPM_GIT_CLEAN_FLAGS) \
		$(YARN_GIT_CLEAN_FLAGS) \
		$(NOFAIL)

-include $(call actions)

export CACHE_ENVS += \
	BABEL \
	BABEL_NODE \
	CLOC \
	CSPELL \
	ESLINT \
	JEST \
	PRETTIER \
	TSC

endif
