function [logm,llcri]=obsexp(obs,exp)

% OBSEXP    Approximate lower 95% credibility interval estimate for shrinkage log obs-exp ratio
%
% [LOGM,LLCRI]=OBSEXP(OBS,EXP) estimates the log of the posterior mean (LOGM) and the log 
% of the lower credibility interval limit (LLCRI )for the observed-to-expected ratio LAMBDA
% based on the observed count OBS and the expected count EXP, and under the assumption
% that EXP~Po(LAMBDA*OBS), with a Ga(alpha,alpha) prior for LAMBDA. 
%
% ====================================================================================
% Written on May 10 2006 by Niklas Noren
% ====================================================================================

% Selected credibility limit
lim=0.025 ;

% Prior parameter
alpha=0.5;


% Posterior parameters
a=obs+alpha;
b=exp+alpha;

m=a./b;

% Binary search
% OBS Matlab's Gammainc function differs from e.g. the definition on
% Wikipedia
if lim<0.5
    a_lim=a./2;
    i=a./2;
else
    a_lim=5.*a;
    i=5*a;
end
d=gammainc(a_lim,a)-lim;
while(max(abs(d))>1e-5)
    a_lim=a_lim+i.*(-0.5+(d<0));
    d=gammainc(a_lim,a)-lim;
    i=i./2;
end
llcri=log2(a_lim./b);

logm=log2(m);