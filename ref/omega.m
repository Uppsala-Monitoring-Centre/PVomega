function [o,o025]=omega(nxyz,nxy,nxz,nyz,nx,ny,nz,n)

% OMEGA  Estimate interaction effects based on ADR reports
%
%   [o,o025]=OMEGA(NXYZ,NXY,NXZ,NYZ,NX,NY,NZ,N) produces an estimate for
%   the interaction between X and Y wrt Z. The input arguments are the
%   joint and marginal counts for the association of interest. o is
%   a shrinkage log-observed-to-expected ratio where the expected database 
%   frequency of Z given X and Y is estimated based 
%   on the database frequencies for the ADR given neither or either of
%   the two drugs, f_0, f_1 and f_2. o025 is the
%   lower 95% credibility interval limit for omega (o).

%========================================================================
% Written by Niklas Noren on July 2006
%========================================================================

% For inspection
f00=(nz-nxz-nyz+nxyz)/(n-nx-ny+nxy)
f10=1-(nx-nxy-nxz+nxyz)/(nx-nxy)
f01=1-(ny-nxy-nyz+nxyz)/(ny-nxy)
f11=nxyz/nxy

% Robustness check against over-estimated background risk
% f00=0

obs=nxyz;
exp=(1-1/(1+max(f00/(1-f00),f10/(1-f10))+max(f00/(1-f00),f01/(1-f01))-f00/(1-f00)))*nxy
g11=(1-1/(1+max(f00/(1-f00),f10/(1-f10))+max(f00/(1-f00),f01/(1-f01))-f00/(1-f00)))
% The same expression unabbreviated
% exp=(1-1/(1+max((nz-nxz-nyz-nxyz)/(n-nx-ny-nz+nxy+nxz+nyz-nxyz),(nxz-nxyz)/(nx-nxy-nxz+nxyz))+max((nz-nxz-nyz-nxyz)/(n-nx-ny-nz+nxy+nxz+nyz-nxyz),(nyz-nxyz)/(ny-nxy-nyz+nxyz))-(nz-nxz-nyz-nxyz)/(n-nx-ny-nz+nxy+nxz+nyz-nxyz)))*nxy

omega0=obsexp(obs,exp)
% Prior parameter
alpha=0.5;

[o,o025]=obsexp(obs+alpha,exp+alpha)


% % Binary search for upper credibility interval limit
% OBS Matlab's Gammainc function differs from e.g. the definition on
% Wikipedia
% a=obs+alpha;
% b=exp+alpha;
% lim=0.975;
% a_lim=2*a;
% i=2*a;
% d=gammainc(a_lim,a)-lim;
% while(abs(d)>1e-5)
%     a_lim=a_lim+i*(-0.5+(d<0));
%     d=gammainc(a_lim,a)-lim;
%     i=i/2;
% end
% omega975=log2(a_lim/b)
