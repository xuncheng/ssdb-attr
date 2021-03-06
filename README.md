# SSDB Attr

[![Build Status](https://travis-ci.org/jianshucom/ssdb-attr.svg?branch=master)](https://travis-ci.org/jianshucom/ssdb-attr)

This gem provides an intuitive interface to define attributes on your ActiveModel class and save them in SSDB server.

# Changelog

### 0.1.5

- Upgrade `activerecord` dependency to support 5.0
- Change `after_commit` callback to use `after_create` & `after_save`

### 0.1.4

- Add `SSDBAttr.load_attrs(objects, *fields)` to load multiple attrs for multiple same objects at one time.

### 0.1.3

- Add `load_ssdb_attrs` to get multiple values from SSDB once to avoid multiple SSDB calls.
