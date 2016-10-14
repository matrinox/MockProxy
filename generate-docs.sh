#!/usr/bin/env bash

rm -rf MockProxy/
rm -rf js/
rm -rf css/
rm *.html
yard
mv doc/* ./
rm -rf doc
