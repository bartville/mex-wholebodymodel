function B_inv = tform2angRateTF(tform, rtype, sequence)
    switch nargin
        case 3
            if ~strcmp(rtype, 'eul')
                error('tform2angRateTF: %s', WBM.wbmErrorMsg.STRING_MISMATCH);
            end
            eul   = WBM.utilities.tform2eul(tform, sequence);
            B_inv = WBM.utilities.eul2angRateTF(eul);
        case 2
            switch rtype
                case 'eul'
                    % use the default ZYX axis sequence ...
                    eul   = WBM.utilities.tform2eul(tform);
                    B_inv = WBM.utilities.eul2angRateTF(eul);
                case 'quat'
                    quat  = WBM.utilities.tform2quat(tform);
                    B_inv = WBM.utilities.quat2angRateTF(quat);
                case 'axang'
                    axang = WBM.utilities.tform2axang(tform);
                    B_inv = WBM.utilities.axang2angRateTF(axang);
                otherwise
                    error('tform2angRateTF: %s', WBM.wbmErrorMsg.STRING_MISMATCH);
            end
        otherwise
            error('tform2angRateTF: %s', WBM.wbmErrorMsg.WRONG_ARG);
    end
end
