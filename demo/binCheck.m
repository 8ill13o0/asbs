fs = 5000; %per channels
C = 8;
vref = 3.3;
voltsPerCount = vref/4095; %12-bit adc
%voltsPerCount = vref/1023; %10-bit adc

fid = fopen('capture_1khztone.bin','r');
address = fread(fid,1,'uint32');
B = fread(fid,'uint16');
fclose(fid);


%figure; plot(B);
%ylabel('count');
%figure; plot(B*voltsPerCount,'-r')
%ylabel('volts');

ch0 = B(1:C:end)*voltsPerCount;
ch1 = B(2:C:end)*voltsPerCount;
ch2 = B(3:C:end)*voltsPerCount;
ch3 = B(4:C:end)*voltsPerCount;
ch4 = B(5:C:end)*voltsPerCount;
ch5 = B(6:C:end)*voltsPerCount;
ch6 = B(7:C:end)*voltsPerCount;
ch7 = B(8:C:end)*voltsPerCount;

N = 30; %number of samples to plot
%{
%figure('units','inches','position',[.5 .5 6 12])
subplot(8,1,1)
plot(ch0(1:N),'o-')
subplot(8,1,2)
plot(ch1(1:N),'o-')
subplot(8,1,3)
plot(ch2(1:N),'o-')
subplot(8,1,4)
plot(ch3(1:N),'o-')
subplot(8,1,5)
plot(ch4(1:N),'o-')
subplot(8,1,6)
plot(ch5(1:N),'o-')
subplot(8,1,7)
plot(ch6(1:N),'o-')
subplot(8,1,8)
plot(ch7(1:N),'o-')
xlabel('sample')
%}


figure;
hold on
plot(ch0(1:N),'o-b','linewidth',2)
plot(ch1(1:N),'o-r','linewidth',2)
plot(ch2(1:N),'o-g','linewidth',2)
plot(ch3(1:N),'o-m','linewidth',2)
legend('ch0','ch1','ch2','ch3')
xlabel('sample number')
title('channels 0-3')

figure;
hold on
plot(ch4(1:N),'o-b','linewidth',2)
plot(ch5(1:N),'o-r','linewidth',2)
plot(ch6(1:N),'o-g','linewidth',2)
plot(ch7(1:N),'o-m','linewidth',2)
legend('ch4','ch5','ch6','ch7')
xlabel('sample number')
title('channels 4-7')


fprintf('%2.1f seconds of data\n',ceil(numel(B)/C)/fs)
nfft = 2048;
df = fs/nfft;

figure;
hold on
title('channels 0-3')

%fft for channel 0

y = fft(ch0(1:nfft));
y = y(1:round(nfft/2))*2/nfft;
fvec = 0:df:(numel(y)-1)*df;
plot(fvec,10*log10(y.*conj(y)),'-b')
xlabel('frequency, Hz')
y(1) = 0;
[val,idx]=max(y.*conj(y));
fprintf('Channel 0: max peak of %2.2f dB (%2.2f V) at %2.2f Hz\n',10*log10(val),sqrt(val),fvec(idx))

%fft for channel 1
y = fft(ch1(1:nfft));
y = y(1:round(nfft/2))*2/nfft;
fvec = 0:df:(numel(y)-1)*df;
plot(fvec,10*log10(y.*conj(y)),'-r')
y(1) = 0;
[val,idx]=max(y.*conj(y));
fprintf('Channel 1: max peak of %2.2f dB (%2.2f V) at %2.2f Hz\n',10*log10(val),sqrt(val),fvec(idx))

%fft for channel 2
y = fft(ch2(1:nfft));
y = y(1:round(nfft/2))*2/nfft;
fvec = 0:df:(numel(y)-1)*df;
plot(fvec,10*log10(y.*conj(y)),'-g')
y(1) = 0;
[val,idx]=max(y.*conj(y));
fprintf('Channel 2: max peak of %2.2f dB (%2.2f V) at %2.2f Hz\n',10*log10(val),sqrt(val),fvec(idx))

%fft for channel 3
y = fft(ch3(1:nfft));
y = y(1:round(nfft/2))*2/nfft;
fvec = 0:df:(numel(y)-1)*df;
plot(fvec,10*log10(y.*conj(y)),'-m')
y(1) = 0;
[val,idx]=max(y.*conj(y));
fprintf('Channel 3: max peak of %2.2f dB (%2.2f V) at %2.2f Hz\n',10*log10(val),sqrt(val),fvec(idx))

legend('ch0','ch1','ch2','ch3')


figure;
hold on
title('channels 4-8')

%fft for channel 4
y = fft(ch4(1:nfft));
y = y(1:round(nfft/2))*2/nfft;
fvec = 0:df:(numel(y)-1)*df;
plot(fvec,10*log10(y.*conj(y)),'-b')
xlabel('frequency, Hz')
y(1) = 0;
[val,idx]=max(y.*conj(y));
fprintf('Channel 4: max peak of %2.2f dB (%2.2f V) at %2.2f Hz\n',10*log10(val),sqrt(val),fvec(idx))

%fft for channel 5
y = fft(ch5(1:nfft));
y = y(1:round(nfft/2))*2/nfft;
fvec = 0:df:(numel(y)-1)*df;
plot(fvec,10*log10(y.*conj(y)),'-r')
y(1) = 0;
[val,idx]=max(y.*conj(y));
fprintf('Channel 5: max peak of %2.2f dB (%2.2f V) at %2.2f Hz\n',10*log10(val),sqrt(val),fvec(idx))

%fft for channel 6
y = fft(ch6(1:nfft));
y = y(1:round(nfft/2))*2/nfft;
fvec = 0:df:(numel(y)-1)*df;
plot(fvec,10*log10(y.*conj(y)),'-g')
y(1) = 0;
[val,idx]=max(y.*conj(y));
fprintf('Channel 6: max peak of %2.2f dB (%2.2f V) at %2.2f Hz\n',10*log10(val),sqrt(val),fvec(idx))

%fft for channel 7
y = fft(ch7(1:nfft));
y = y(1:round(nfft/2))*2/nfft;
fvec = 0:df:(numel(y)-1)*df;
plot(fvec,10*log10(y.*conj(y)),'-m')
y(1) = 0;
[val,idx]=max(y.*conj(y));
fprintf('Channel 7: max peak of %2.2f dB (%2.2f V) at %2.2f Hz\n',10*log10(val),sqrt(val),fvec(idx))

legend('ch4','ch5','ch6','ch7')