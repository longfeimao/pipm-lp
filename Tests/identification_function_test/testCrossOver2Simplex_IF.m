function testCrossOver2Simplex_IF
% FUNCTION testCrossOver2Simplex_IF
%
% -------------------------------------------------------------------------
%
% This function is used to compare simplex iteration counts for the
% algorithms with and without perturbations.
% 
% This test runs with identification function being the option for
% active-set prediction.
%
% -------------------------------------------------------------------------
%
% How to use this script:
%   1. Run the script
%   2. Choose the test set
%   3. Check the results (.mat, .pdf, .eps)
%
% -------------------------------------------------------------------------
% 24 March 2013
% Yiming Yan
% University of Edinburgh

%% %%%%% %%%%%%% %%%%%%% --- Main Func --- %%%%%%% %%%%%%% %%%%% %%
close all;
clc;

%% Setup
[Type, numTestProb, params_per, params_unper] = setup_crossover;

% For random test only
seed = 1;                   % Seed for random number generator

% For netlib test only
nameOfProbSet = 'testNetlib.txt';

% Options for the plots
options_evalPerf = [];
% options_evalPerf.solverNames = {'With perturbations' 'Without perturbations'};
options_evalPerf.solverNames = {'Algorithm 6.1' 'Algorithm 6.2'};
options_evalPerf.fileName = [ 'crossover_to_simplex_test_IF' Type];
options_evalPerf.logplot = 1;
options_evalPerf.Quiet = 0;
options_evalPerf.isCaptions = 0;

logFileName = [options_evalPerf.fileName '.log'];

if exist(fullfile(cd, logFileName),'file')
    delete(logFileName);
end

diary(logFileName);
%% Run the test
fprintf('============================== Crossover Tests ==============================\n');

printHeader;

%% Initialise
switch Type
    case 'netlib'
        % read in the name of all test priblems and stoe them in a cell
        prob2test = readProbSet(nameOfProbSet);
        
        % get the number of test problems
        numTestProb = length(prob2test);
        
        %fprintf('Netlib: In total %d problems detected.\n',numTestProb);
        
    case {'random', 'random_degen'}
        rng('default');
        rng(seed);
        prob2test =  strtrim( cellstr( num2str((1:numTestProb)', 'random_%d') ) );
    otherwise
        return;
end

i = 1;

splxIter_per = zeros(numTestProb,1);
splxIter_unp = splxIter_per;
mu_per       = splxIter_per;
mu_unp       = splxIter_per;
ipm_iter     = splxIter_per;
basis_diff   = splxIter_per;

%% Main loop
while i<=numTestProb
    switch Type
        case 'netlib'
            % load test problems
            load(prob2test{i});
            [A,b,c,FEASIBLE]=myPreprocess(A,b,c,lbounds,ubounds,BIG);
            
        case 'random'
            [A,b,c] = generateRandomProb('m_min',10,'m_max',200,...
                'n_min',20,'n_max',500);
            
        case 'random_degen'
            [A, b, c] = generateDegenProb('m_min',10,'m_max',200,...
                'n_min',20,'n_max',500);
    end
    
    %% Solve the problem using pipm
    per = pipm(A,b,c,params_per); per.solve;
    
    params_unper.maxIter = per.getIPMIterCount;
    unper = pipm(A,b,c,params_unper); unper.solve;
    
    if per.status.exitflag == 0 && per.getMu > 1e-03
        Prob = [ prob2test{i} '*' ];
    else
        Prob = prob2test{i};
    end
    
    if per.getSplxIter > unper.getSplxIter
        Prob = [ '\textbf{' Prob '}'];
    end
    
       
    %% Collect data
    splxIter_per(i) = per.getSplxIter; splxIter_unp(i) = unper.getSplxIter;
    mu_per(i)       = per.getMu;       mu_unp(i)       = unper.getMu;
    
    ipm_iter(i)     = per.getIPMIterCount;
    basis_diff(i)   = checkBasisDiff(per.crossover.basis, unper.crossover.basis);
    
    printContent(Prob, per, unper, basis_diff(i));
    
    %% Increment counter
    i = i+1;
end
clearvars A b c lbounds ubounds NAME i Prob per unper BIG FEASIBLE ifree;
save([ 'crossover_to_simplex_test_IF_' Type '.mat']);

%% Calculate the average
fprintf('---------------------------------------------------------------------\n');
tmp_splxIter_per = splxIter_per; tmp_splxIter_unp = splxIter_unp;
tmp_splxIter_per(isnan(tmp_splxIter_per)) = [];
tmp_splxIter_unp(isnan(tmp_splxIter_unp)) = [];
% The average value of splxIter_per and _unp are calculated after removed
% failures.
fprintf('%10s & %4s & %4s & %9.2e & %9.2e & %9d & %9.2f & %9d & %9d\n',...
    'Average:', ' ', ' ', mean(mu_per), mean(mu_unp),...
    round(mean(ipm_iter)), mean(basis_diff),...
    round(mean(tmp_splxIter_per)), round(mean(tmp_splxIter_unp)));

%% Check the degree of difference between the two bases
fprintf('\n============================ Basis_Diff ============================\n');
fprintf('Rel. difference between bases generated from perturbed and unperturbed algs\n\n');

fprintf('%8s %4s %4s\n','Average', 'Min', 'Max');
fprintf('%8.2f %4.2f %4.2f\n', mean(basis_diff), min(basis_diff), max(basis_diff));
fprintf('\n%s\n\n','Problems with less than 10% difference:');
diff_less_10 = find(basis_diff < 0.1);
fprintf('%4s %11s %8s\n', 'Idx.', 'Probs.', 'Rel_Diff');
for j = 1:length(diff_less_10)
    fprintf('%4d %11s %8.2f\n',...
        diff_less_10(j),...
        prob2test{diff_less_10(j)},...
        basis_diff(diff_less_10(j)) );
end

fprintf('\nPlotting histogram for basis_diff...\n');
plotBasesDiffHist(basis_diff, Type);

%% Plot relative performance chart
T = [splxIter_per splxIter_unp];

% Remove problems that cannot be solved by two
indx = find(sum(isnan(T),2) > 1);
T(indx,:) = [];
fprintf('\n============================ Rel Performance ============================\n');
fprintf('\n# of Probs removed: %d\n', length(indx));
fprintf('Problems removed: \n');
fprintf('%s\n',prob2test{indx})

profiles = evalPerformance(T,options_evalPerf);
profiles.relativePerformacne;

diary off;
end

%% %%%%% %%%%%%% %%%%%%% --- Main Func End --- %%%%%%% %%%%%%% %%%%% %%


function [Type, numTestProb, params_per, params_unper] = setup_crossover
% Determine which set of problems to test on.
% Choose from the following three values:
% random, netlib, random_degen
fprintf('Pls choose the test set [1-3]: \n');
fprintf('\t [1]. Random test (primal nondegenerate)\n');
fprintf('\t [2]. Random test (primal-dual degenerate)\n');
fprintf('\t [3]. Netlib test  \n');
usrinput_type = input('Your choice here [1-3]: ');
if usrinput_type == 1
    Type = 'random';
elseif usrinput_type == 2
    Type = 'random_degen';
elseif usrinput_type == 3
    Type = 'netlib';
else
    error('testCorrectionRatios: please choose a number from the above list');
end

% Determine which active-set prediction strategy to use.
% In the paper, we mainly show the results of using a constant as threshold
% value ('conservCutoff'). In the last part the paper, we also mentioned
% the use of identification fucntion ('conservIdFunc'). Both strategies have
% been implemented.
actvPredStrtgy = 'conservIdFunc'; % Default value conservCutoff
% Alternative: conservCutoff

numTestProb = 100;          % Set to 10 for demo. 100 for real test.

% With perturbations
params_per.verbose = 0;
params_per.iPer = 1e-02;
params_per.mu_cap = 1e-03;
%params_per.tol = 1e-32;
params_per.actvPredStrtgy = actvPredStrtgy;
params_per.doCrossOver = 1;

% Without perturbations
params_unper.verbose = 0;
params_unper.iPer = 0;
params_unper.actvPredStrtgy = actvPredStrtgy;
%params_unper.tol = 1e-32;
params_unper.doCrossOver = 1;
end

function basis_diff = checkBasisDiff( basis1,  basis2 )
% BASIS_DIFF This function calculates the degree of difference between
%            two bases generated from perturbed and unperturbed
%            algorithms
%
% Define relative difference:
%     relative difference =
%           ( union of basis1 and basis2 - intersection of these two )
%           / union of these two bases
%

union_bases = union(basis1, basis2);
basis_diff = setdiff(union_bases, intersect(basis1,basis2));
basis_diff = length(basis_diff)/length(union_bases);

end

function plotBasesDiffHist(basis_diff, Type)
scrsz = get(0,'ScreenSize');
h1 = figure('Position',...
    [0 0 scrsz(3)/3 scrsz(4)/3],...
    'Name','Relative Difference between Bases',...
    'NumberTitle','off');
axe_h = gca;
hist(axe_h, basis_diff);
hist_filename = [ 'crossover_to_simplex_test_' Type '_basis_diff_hist.eps'];
print(h1, '-depsc', hist_filename);
[~,~] =eps2pdf(hist_filename);
end

function printHeader
% Header: 1       2   3      4     5     6     7   8     9
fprintf('%10s & %4s & %4s & %9s & %9s & %9s & %9s & %9s & %9s \\\\ \n',...
    'Prob', 'm', 'n', 'mu_per', 'mu_unp', 'iter_ipm', 'B_diff', 'splx_per', 'splx_unp');
end

function printContent(Prob, per, unper, basis_diff)
    % Iter:  1       2     3     4       5       6      7      8     9
    fprintf('%10s & %4d & %4d & %9.2e & %9.2e & %9d & %9.2f & %9d & %9d \\\\ \n',...
        Prob, per.prob.m, per.prob.n, per.getMu, unper.getMu,...
        per.getIPMIterCount, basis_diff, per.getSplxIter, unper.getSplxIter);
end
