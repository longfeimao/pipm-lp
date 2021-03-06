clear; clc;
% update solverNames
algNames = {'Algorithm 6.1' 'Algorithm 6.2'};
%algNames = {'With perturbations' 'Without perturbations'}

%% correction rations
folder = 'correction_ratio_test';
files = dir([folder '/correction_ratio_test_*.mat']);

for i=1:length(files)
    load([folder '/' files(i).name]);
    Legends = algNames;
    range = stopAtRangeL : stopAtRangeU;
    plotCorrectionRatios(falsePrediction, missedPrediction,...
        correctionR, avgResidual, range, Legends, fileName);
end

%% crossover
folder = 'crossover_test';
files = dir([folder '/crossover_to_simplex_test_*.mat']);
for i=1:length(files)
    load([folder '/' files(i).name]);
    options_evalPerf.solverNames = algNames;
    T = [splxIter_per splxIter_unp];
    
    % Remove problems that cannot be solved by two
    indx = find(sum(isnan(T),2) > 1);
    T(indx,:) = [];
    profiles = evalPerformance(T,options_evalPerf);
    profiles.relativePerformacne;
end
