clear all;
load('resultados_isadora_JL_100_ciclos_4_m_1.mat');
 cropini=7; 
 cropfim=44;
 meio=floor(0.5*(cropfim-cropini)); % define velocidade no meio do tubo (a mais alta)


amost_tempo=4;
acq.vr(meio,amost_tempo)% mostra a velocidade calculada para a amostra do tempo(amost_tempo) definida e para a posição definida(meio)
valoresmeio(1,:)=acq.vdatas(meio,amost_tempo,:); %;salva os valores complexos utilizados para a amostra do tempo(amost_tempo) 
% definida e para a posição definida(meio)
%velocidades são negativas porque o fluxo da água é contra o transdutor!

%%

%como as velocidades, vr, foram calculadas!

auto= [2.142172419131322e+05 - 2.678153321544330e+05i]
phi_est =  atan2(imag(auto),real(auto));
vr = acq.c*acq.prf/(4*pi*acq.fc) * phi_est  

%% outros valores velocidade próximo da borda do tubo (mais baixa)
borda=cropini;

amost_tempo=4;
acq.vr(borda,amost_tempo)% mostra a velocidade calculada para a amostra do tempo(amost_tempo) definida e para a posição definida(meio)
valoresborda(1,:)=acq.vdatas(borda,amost_tempo,:); %;salva os valores complexos utilizados para a amostra do tempo(amost_tempo) 
%% borda +1
%% outros valores velocidade próximo da borda do tubo 
borda1=cropini+1;

amost_tempo=4;
acq.vr(borda1,amost_tempo)% mostra a velocidade calculada para a amostra do tempo(amost_tempo) definida e para a posição definida(meio)
valoresborda1(1,:)=acq.vdatas(borda1,amost_tempo,:); %;salva os valores complexos utilizados para a amostra do tempo(amost_tempo) 
%%
valreal=single(imag(valoresmeio));
valreal=valreal';
filename = 'testdata.xlsx';
% filename = 'testdata.xlsx';
%writematrix(A,filename,'Sheet',1,'Range','E1:I5')
valespacos=zeros(1,129*4);
valespacos(1,1:4:end)=valreal;
valespacos=valespacos';
writematrix(valespacos,filename,'Sheet',1,'Range','a1:a516')

sind(18)
