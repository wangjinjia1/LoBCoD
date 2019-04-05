% Multi-Exposure Image Fusion Demo script.

% This script demonstrates LoBCoD for Multi-Exposure image fusion.
% The script loads the following variables:
%  
% (1) D_init - The initial dictionary used to represent the edge-components.
% (2) Gx, Gy - The gradient matrices used for gradient calculation in
%              the horizontal and vertical directions.
% (3) G      - The gradient matrix "G = eye + mu*(Gx'*Gx+Gy'*Gy)".
% 

addpath('functions')
addpath mexfiles;
addpath image_helpers;
addpath('vlfeat/toolbox');
addpath('utilities');
addpath(genpath('spams-matlab'));
vl_setup();

I_org = cell(1,2);
I_org{1} = double((imread('datasets\Multi_Exposure\B.jpg')));
I_org{2} = double((imread('datasets\Multi_Exposure\C.jpg')));

I_org_1 = I_org{1}(101:400,101:500,:);
I_org_2 = I_org{2}(101:400,101:500,:);


I_org{1}= imresize(I_org_1,[210 210]);
I_org{2}= imresize(I_org_2,[210 210]);


I_lab = cell(1,2);
I_lab{1} = rgb2lab(I_org{1});
I_lab{2} = rgb2lab(I_org{2});


load('datasets\Multi_Exposure\param.mat');
lambda =1;
mu = 5;
n =  sqrt(size(D_init,1));
m = size(D_init,2);
MAXITER_pursuit = 50;

I = cell(1,2);
sz = cell(1,2);

I{1} = I_lab{1}(:,:,1);
I{2} = I_lab{2}(:,:,1);

sz{1} = size(I{1});
sz{2} = size(I{2});
sz_vec = sz{1}(1)*sz{1}(2);
N=length(I);
patches = myim2col_set_nonoverlap(I{1}, n);


MAXITER = 2;
Xb = cell(1,N);
X_resb = cell(1,N);
X_res_e = cell(1,N);
alpha =  cell(1,N);
Xe = cell(1,N);
epsilon = 1e-20; 

params = [];
params.lambda = lambda;
params.MAXITER = MAXITER_pursuit;
params.D = D_init;
params.Train_on = false(1);


for k=1:N
    Xe{k} = zeros(size(I{k}));
end
for outerIter = 1 : MAXITER
    for i=1:N
        X_resb{i} = I{i}-Xe{i};
        X_resb{i} = padarray(X_resb{i},[1 1],'symmetric','both');
        Xb{i} = reshape(lsqminnorm(G,X_resb{i}(:)),(sz{i}(1)+2),(sz{i}(2)+2));
        Xb{i} = real(Xb{i}(1:sz{1}(1),1:sz{1}(2)));
        X_res_e{i} = I{i}-Xb{i};
  
    end

    params.Ytrain = X_res_e;
    [Xe,objective,avgpsnr,sparsity,totTime,alpha,~] = LoBCoD(params);
    D_opt = D_init;

end

%% Fusion

A = cell(1,N);
k = (1/6)*ones(6,6);
[feature_maps,~] = create_feature_maps(alpha,n,m,sz{1},D_opt);

fused_feature_maps = cell(1);
fused_feature_maps{1} = cell(size(feature_maps{1}));
Clean_xe = cell(1,length(patches));

A{1} = abs(feature_maps{1}{1});
A{2} = abs(feature_maps{2}{1});
for j=2:m
   A{1} = A{1}+abs(feature_maps{1}{j});
   A{2} = A{2}+abs(feature_maps{2}{j});
end
A{1} = rconv2(A{1},k);
A{2} = rconv2(A{2},k);

for j=1:m
    fused_feature_maps{1}{j} = (A{1}>=A{2}).*feature_maps{1}{j}+(A{1}<A{2}).*feature_maps{2}{j};
end

[alpha_fused,I_rec] = extract_feature_maps(fused_feature_maps,n,m,sz{1},D_opt);
for j=1:n^2 
   Clean_xe{j}= D_opt*alpha_fused{1}{j};
end

%%
epsilon = 300;
fused_image_e = mycol2im_set_nonoverlap(Clean_xe,sz{1}, n);
fused_image_b = 0.1*Xb{1}+0.9*Xb{2};
ours_lab = double(I_lab{1});
ours_lab(:,:,1)= fused_image_e+fused_image_b;
ours_lab(:,:,2) = (A{1}>=(A{2}+epsilon)).*double(I_lab{1}(:,:,2))+(A{1}<(A{2}+epsilon)).*double(I_lab{2}(:,:,2));
ours_lab(:,:,3) = (A{1}>=(A{2}+epsilon)).*double(I_lab{1}(:,:,3))+(A{1}<(A{2}+epsilon)).*double(I_lab{2}(:,:,3));

%%

figure; 
subplot(1, 3,1);  imshow(uint8(I_org{1})); title('Underexposed image'); axis off
subplot(1, 3,2); imshow(uint8(I_org{2})); title('Overexposed image'); axis off
subplot(1, 3,3); imshow(uint8(lab2rgb(ours_lab)));  title('fused image'); axis off
