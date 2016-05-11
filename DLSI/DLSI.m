function [D, X, rt] = DLSI(Y, Y_range, opts)
% * function `[D, X, rt] = DLSI(Y, Y_range, opts)`
% * The main DLSI algorithm 
% * INPUT: 
%   - `Y, Y_range`: training samples and their labels 
%   - `opts`: 
%     + `opts.lambda, opts.eta`: `lambda` and `eta` in the cost function 
%     + `opts.max_iter`: maximum iterations. 
% * OUTPUT:
%   - `rt`: total running time of the training process.   
% * `[D, X, rt] = argmin_{D, X}(\sum 0.5*\|Y_c - D_c X_c\|_F^2) + 
%           \lambda*norm1(X) + 0.5*eta * \sum_{i \neq c} \|D_i^T D_c\|_F^2`
% * updating `X`:
%   `Xi = arg\min 0.5*||Y_c - D_c X_c\|_F^2 + \lambda \|X_c\|`
% * updating `D`:
%   `Di = \arg\min \|Y_c - D_c X_c\|_F^2 + \eta \|D_{\c}^T D_c\|_F^2`
% -----------------------------------------------
% Author: Tiep Vu, thv102@psu.edu, 4/14/2016
%         (http://www.personal.psu.edu/thv102/)
% -----------------------------------------------
    D_range = opts.D_range;
    C = numel(D_range) - 1;
    D = zeros(size(Y,1), D_range(end));
    % X = zeros(size(D,2), size(Y,2))

    %% ========= X should be stored in cell ==============================
    clear X;
    for i = 1: C 
        rows = D_range(i+1) - D_range(i);
        cols = Y_range(i+1) - Y_range(i);
        X{i} = zeros(rows, cols);
    end 
    lambda = opts.lambda;
    eta = opts.eta;    
    %% ========= init ==============================
    optsinit = opts;
    optsinit.show = 0;
    if opts.verbal
        fprintf('Cost = %5f\n', DLSI_cost(Y, Y_range, D, D_range, X, opts));
        fprintf('Initializing...\n');
    end 
    optsinit.max_iter = 50;
    for i = 1: C        
        if opts.verbal
            fprintf('Class: %2d. ', i);
        end 
        Yi = get_block_col(Y,i,Y_range);        
        [Di, X{i}] = ODL(Yi, D_range(i+1) - D_range(i), lambda, optsinit, ...
            'fista');
        D(:, D_range(i) + 1: D_range(i+1)) = Di;
    end 
    % if opts.show 
    if opts.verbal
        fprintf('\n');
        fprintf('Cost = %5f\n', DLSI_cost(Y, Y_range, D, D_range, X, opts));
    end 
    %%
    iter = 0;
    optsX.max_iter = 300;
    optsX.show = false;
    optsD.show = false;
    optsD.max_iter = 200;
    %%
    costD = 0;
    costX = 0;
    tic;
    while iter < opts.max_iter
        iter = iter + 1;
        %% ========= update X ==============================
        for i = 1: C 
            Yi = get_block_col(Y, i, Y_range);
            Di = get_block_col(D, i, D_range);
            X{i} = lasso_fista(Yi, Di, X{i}, lambda, optsX);
        end 
        if opts.verbal
            costX = DLSI_cost(Y, Y_range, D, D_range, X, opts);
            fprintf('iter = %3d | costX = %5f\n', iter, costX);
        end 
        %% ========= update D ==============================
        for i = 1: C 
            D_comi = D;
            D_comi(D_range(i)+1: D_range(i+1)) = [];
            Di = D(:, D_range(i)+1: D_range(i+1));
            Yi = get_block_col(Y, i, Y_range);
            Di = DLSI_updateD(Yi, X{i}, Di, D_comi', eta, optsD);
            D(:, D_range(i)+1: D_range(i+1)) = Di;
        end 
        %%
        t0 = toc;
        if opts.verbal 
            costD = DLSI_cost(Y, Y_range, D, D_range, X, opts);
            fprintf('iter = %3d | costD = %5f', iter, costD);
            t = t0*(opts.max_iter - iter)/iter;
            time_estimate(t);
        end 
        if t0 > 20*3600 % > 20h 
            break;
        end 
    end 
    rt = toc;
end 
