subroutine manager
use globals
use auxiliary
implicit none
logical, allocatable :: start(:)
integer :: seed,ierr,worker,exit_tags_sent,tag,p,active_num_procs,nworkers
double precision :: managing_time,waiting_time,record_time
integer, dimension(mpi_status_size) :: status
double precision :: buf
double precision, allocatable, dimension(:) :: eigs
character(len=256) :: eigs_filename

! Man init start
man_init_time = MPI_wtime()
! Set matrix size and number of eigenvalues
call init(active_num_procs)
nworkers = active_num_procs - 1

! Print params to console
if(proc_num.eq.0) then
    print *,'|| Starting Program ||'
    print *,'Matrix size:',n
    print *,'Eigenvalues:',ndat
    print *,'  Num Procs:',num_procs
    print *,'      Managers = 1, Workers =',nworkers
    print *,'-------------------'
    print *,'Running...'
end if
! Broadcast matrix size
call mpi_bcast(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
! Allocate array for received eigenvalues
allocate(eigs(ndat))
allocate(start(1:nworkers))

start=.true.
exit_tags_sent=0
failed=0
shur_fallbacks=0
write(eigs_filename,'(a,i0,a,i0,a)') 'data/results/eigs_N',n,'_D',ndat,'.dat'
open(22,file=trim(eigs_filename), position='append')

man_init_time = MPI_wtime() - man_init_time
! man init end


! Receive data until at least ndat have been received
do while(.true.)
   ! For each worker check if a seed is needed
   managing_time = MPI_wtime()
   do p=1,nworkers
      if(start(p)) then
         call get_random_seed(seed)
         if(recvd.lt.ndat-nworkers+1) then
            tag=DEFAULT_TAG
         else
            tag=EXIT_TAG
            exit_tags_sent=exit_tags_sent+1
            print *,'Worker ',p,' exiting...'
         end if
         call mpi_send(seed,1,MPI_INTEGER,p,tag,MPI_COMM_WORLD,ierr)
!         print *,'Manager sent seed ',seed,' to worker ',p
         start(p)=.false.
      end if
   end do
   managing_time = MPI_wtime() - managing_time
   man_managing_time = man_managing_time + managing_time
   if(exit_tags_sent.eq.nworkers) then
        print *,'Job Complete - Exiting Manager...'
      exit
   end if
   
   waiting_time = MPI_wtime()
   call mpi_recv(buf,1,MPI_DOUBLE_PRECISION,MPI_ANY_SOURCE,MPI_ANY_TAG,MPI_COMM_WORLD,status,ierr)
   waiting_time = MPI_wtime() - waiting_time
   man_waiting_time = man_waiting_time + waiting_time

   record_time = MPI_wtime() 
   worker = status(MPI_SOURCE)
   tag = status(MPI_TAG)
   if(tag.eq.0) then
      recvd=recvd+1
      eigs(recvd)=buf
      write(22,'(i4,e14.7)') worker,buf
   else
      failed=failed+1
      print '(i5,a7,i5,a8)',recvd,' received, ',failed,' failed'
   end if
   start(worker)=.true.
    record_time = MPI_wtime() - record_time
    man_record_time = man_record_time + record_time
   
end do

! Print summary to console
print *,'-------------------'
print *,'Summary:'
print *,'  Num Procs:',num_procs
print *,'      Managers:',1
print *,'      Workers:',nworkers
print *,'  Matrix size:',n
print *,'  Eigenvalues:',ndat
print *,'  Successes:',recvd
print *,'  Failures:',failed
print *,'  Shur Fallbacks:',shur_fallbacks
close(22)

deallocate(eigs)
deallocate(start)
return
end subroutine manager

subroutine init(active_num_procs)
use globals
implicit none
integer, intent(out) :: active_num_procs

! Take n and ndat from command line
call parse_command_line(active_num_procs)


return
end subroutine init


subroutine parse_command_line(active_num_procs)
   use globals
   implicit none
   integer, intent(out) :: active_num_procs
   integer :: argc,idx,parsed_value,requested_num_procs
   character(len=64) :: arg,value

  n = 1000
  ndat = 100
  requested_num_procs = num_procs

  argc = command_argument_count()
  idx = 1
  do while (idx .le. argc)
     call get_command_argument(idx,arg)
     select case (trim(arg))
     case ('-N')
        if (idx .ge. argc) call usage_and_stop('Missing value for -N')
        idx = idx + 1
        call get_command_argument(idx,value)
        call parse_positive_integer(value,'-N',parsed_value)
        n = parsed_value
     case ('-D','-NDAT')
        if (idx .ge. argc) call usage_and_stop('Missing value for -D')
        idx = idx + 1
        call get_command_argument(idx,value)
        call parse_positive_integer(value,'-D',parsed_value)
        ndat = parsed_value
     case default
        call usage_and_stop('Unknown argument: '//trim(arg))
     end select
     idx = idx + 1
  end do

  if (requested_num_procs .lt. 1) then
     call usage_and_stop('-P must be at least 1')
  end if
  if (requested_num_procs .gt. num_procs) then
     call usage_and_stop('Requested -P exceeds MPI world size from mpirun -np')
  end if

  active_num_procs = requested_num_procs
end subroutine parse_command_line

subroutine parse_positive_integer(text,flag_name,parsed_value)
  character(len=*), intent(in) :: text,flag_name
  integer, intent(out) :: parsed_value
  integer :: io

  read(text,*,iostat=io) parsed_value
  if (io .ne. 0 .or. parsed_value .le. 0) then
     call usage_and_stop('Invalid value for '//trim(flag_name)//': '//trim(text))
  end if
end subroutine parse_positive_integer

subroutine usage_and_stop(message)
    character(len=*), intent(in) :: message

    print *, trim(message)
   print *, 'Usage: ./test.x [-N <matrix_size>] [-D <num_eigs>] [-P <num_procs>]'
   print *, '  -N <num>  Matrix size n (default: 1000)'
   print *, '  -D <num>  Number of eigenvalues ndat (default: 100)'

    stop 1
end subroutine usage_and_stop