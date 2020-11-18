clc,clear,close all;
currentpath=cd ('d:\signal-processing\');
[y,fs]=audioread("test_english.wav")
whos y
whos fs