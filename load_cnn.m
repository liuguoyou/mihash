function [Xtrain, Ytrain, Xtest, Ytest] = load_cnn(dataset, opts)

	tic;
	if strcmp(dataset, 'cifar')
		if opts.windows
			basedir = '\\ivcfs1\codebooks\hashing_project\data';
		else
			basedir = '/research/codebooks/hashing_project/data';
		end
		load([basedir '/cifar-10/descriptors/trainCNN.mat']); % trainCNN
		load([basedir '/cifar-10/descriptors/traininglabelsCNN.mat']); % traininglabels
		load([basedir '/cifar-10/descriptors/testCNN.mat']); % testCNN
		load([basedir '/cifar-10/descriptors/testlabelsCNN.mat']); % testlabels
		X = [trainCNN; testCNN];
		Y = [traininglabels; testlabels];
		T = 100;
		% fully supervised
		[Xtrain, Ytrain, Xtest, Ytest] = split_train_test(X, Y, T);

	elseif strcmp(dataset, 'places')
		if opts.windows
			basedir = '\\kraken\object_detection\data';
		else
			basedir = '/research/object_detection/data';
		end
		% loads variables: pca_feats, labels, images
		% NOTE: labels are from 0 to 204, we add 1 to each to make them 1 to 205
		%       because we want to use 0 to indicate unlabeled
		load([basedir '/places/places_alexnet_fc7pca128.mat']);
		X = double(pca_feats);
		Y = labels + 1;
		T = 20;
		L = opts.labelspercls;  % default 2500, range [500, 5000]
		% semi-supervised
		[Xtrain, Ytrain, Xtest, Ytest] = split_train_test(X, Y, T, L);

	else, error(['unknown dataset: ' dataset]); end

	whos Xtrain Ytrain Xtest Ytest
	myLogInfo('Dataset "%s" loaded in %.2f secs', dataset, toc);
end

% --------------------------------------------------------
function [Xtrain, Ytrain, Xtest, Ytest] = split_train_test(X, Y, T, L)
	% X: original features
	% Y: original labels
	% T: # test points per class
	% L: [optional] # labels to retain per class
	if nargin < 4, L = 0; end

	% normalize features
	X = bsxfun(@minus, X, mean(X,1));  % first center at 0
	X = normalize(X);  % then scale to unit length
	D = size(X, 2);

	labels = unique(Y);
	nclass = length(labels);
	ntest  = nclass * T;
	ntrain = size(X, 1) - ntest;
	Xtrain = zeros(ntrain, D);  Xtest = zeros(ntest, D);
	Ytrain = zeros(ntrain, 1);  Ytest = zeros(ntest, 1);
	
	% construct test and training set
	cnt = 0;
	for i = 1:nclass
		% find examples in this class, randomize ordering
		ind = find(Y == labels(i));
		n_i = length(ind);
		ind = ind(randperm(n_i));

		% assign test
		Xtest((i-1)*T+1:i*T, :) = X(ind(1:T), :);
		Ytest((i-1)*T+1:i*T)    = labels(i);

		% assign train
		st = cnt + 1; 
		ed = cnt + n_i - T;
		Xtrain(st:ed, :) = X(ind(T+1:end), :);
		Ytrain(st:ed)    = labels(i);
		if L > 0  
			% if requested, hide some labels
			if st + L > ed
				warning(sprintf('%s Class%d: ntrain=%d<%d=labelspercls, keeping all', ...
					labels(i), n_i-T, L));
			else
				Ytrain(st+L: ed) = 0;
			end
		end
		cnt = ed;
	end

	% randomize again
	ind    = randperm(size(Xtrain, 1));
	Xtrain = Xtrain(ind, :);
	Ytrain = Ytrain(ind);
	ind    = randperm(size(Xtest, 1));
	Xtest  = Xtest(ind, :);
	Ytest  = Ytest(ind);
end