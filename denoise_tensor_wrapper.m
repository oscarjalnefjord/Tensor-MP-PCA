function denoise_tensor_wrapper(im_file,bval_file,bvec_file,outbase,window,other_file)
% Wrapper function to call denoise_recursive_tensor() 
% with nifti input/output.
% 
% Currently supports one dimension on top of b-value 
% and b-vector, e.g. TE, with file in format equivalent 
% to bval file.
%

% Read files
info = niftiinfo(im_file);
im = niftiread(info);
b = importdata(bval_file, ' ');
v = importdata(bvec_file, ' ');
if nargin > 5
    o = importdata(other_file, ' ');
else
    o = [1];
end

% To tensor structure
ub = unique(b);
uv = unique(v(:,sum(abs(v),1)>1)','rows')';
uo = unique(o);
tensor = zeros([size(im,1) size(im,2) size(im,3) size(uv,2) size(ub,2) size(uo,2)]);
idxb0 = find(b==0, size(uv,2)*size(uo,2)); % handle multiple b = 0
for oi = 1:size(uo,2)
    for bi = 1:size(ub,2)
        for vi = 1:size(uv,2)
            if ub(bi) == 0
                idx = idxb0(vi+(oi-1)*size(uv,2));
            else
                idx = find((b==ub(bi)) & (sum(uv(:,vi) == v,1)==3) & (o==uo(oi)));
            end
            tensor(:,:,:,vi,bi,oi) = im(:,:,:,idx);
        end
    end
end

% Denoise
[denoised,Sigma2,P,SNR_gain] = denoise_recursive_tensor(tensor,window,'indices',{1:3 4 5 6});

% Back to 4D
im_dn = zeros(size(im));
for oi = 1:size(uo,2)
    for bi = 1:size(ub,2)
        for vi = 1:size(uv,2)
            if ub(bi) == 0
                idx = idxb0(vi+(oi-1)*size(uv,2));
            else
                idx = find((b==ub(bi)) & (sum(uv(:,vi) == v,1)==3) & (o==uo(oi)));
            end
            im_dn(:,:,:,idx) = denoised(:,:,:,vi,bi,oi);
        end
    end
end

% Save to file
info_dn = info;
info_dn.Datatype = 'double';
niftiwrite(im_dn,outbase,info_dn,"Compressed",true);

info_dn.ImageSize = [size(Sigma2,1) size(Sigma2,2) size(Sigma2,3) 1];
niftiwrite(Sigma2,[outbase '_Sigma2'], info_dn, "Compressed",true);
niftiwrite(mean(im_dn(:,:,:,idxb0),4)./sqrt(Sigma2),[outbase '_SNR'],info_dn, "Compressed",true);
niftiwrite(SNR_gain,[outbase '_SNRgain'], info_dn,"Compressed",true);

info_dn.ImageSize = size(P);
niftiwrite(P,[outbase '_P'],info_dn,"Compressed",true);
