- 322p ~ 341p

### 실행 계획 분석
#### 컬럼s (계속)
- Extra
    - 고정된 몇개의 문장이 일반적으로 2~3개씩 같이 표시되면서 실행계획이나 결과에 대한 경고 등을 보여준다.
    - using temporary : 임시테이블이 사용됐음을 나타낸다. 쿼리를 처리하면서 중간 결과를 담아두기 위해사 용한다. 생성 스코프(메모리/디스크)는 실행계획만으론 알 수 없다.
    ```mysql
    explain
    select e.gender, min(emp_no)
    from employees e group by e.gender order by min(emp_no);
    ```
    - using where : 스토리지 엔진에서 읽은 데이터가 MySQL 엔진에서 별도의 필터링이나 가공 없이
    그대로 클라이언트로 전달되는 경우 이 메시지가 표시되지 않는다.
    ```mysql
    # emp_no의 범위 제한 조건은 각 스토리지 엔진 레벨에서 처리 되지만,
    # gender의 체크 조건은 MySQL 엔진 레이어에서 처리된다.
    explain
    select *
    from employees where emp_no between 10001 and 10100 and gender='F';
    ```
    - using where with pushed condition : 'condition push down' 이 적용됐음을 알리는 메시지다.
     
- EXPLAIN EXTENDED
    - 필터링이 얼마나 효율적으로 실행됐는지를 알기 위한 키워드이다.
    - filtered 컬럼은 MySQL 엔진에 의해 필터링되어 제거된 레코드를 제외하고 최종적으로 레코드가 얼마나 남았는지 비율을 표시한다(예측값).
    ```mysql
    explain extended
    select *
    from employees where emp_no between 10001 and 10100 and gender='F';
    ```
    - explain extended 실행 후 'show warnings' 실행은 옵티마이저가 쿼리를 어떻게 해석했는지를 보여준다.
    
### MySQL 의 주요 처리 방식.
- 풀 테이블 스캔만 스토리지 엔진에서 처리되는 내용이며 나머지 내용은 MySQL 엔진에서 처리되는 내용이다. 

#### 풀 테이블 스캔 
- 주로 다음 조건일 때 선택된다.
```
- 레코드 건수가 너무 작아서 인덱스를 사용하는 것보다 빠른경우
- where나 on절에 인덱스를 이용할 조건이 없는 경우
- 인덱스 레인지 스캔을 쓸 수 있는 쿼리라도 옵티마이저가 판단하기에 조건 일치 레코드 건수가 너무 많은 경우
- max_seeks_for_key 를 특정 값 N 으로 설정하면 MySQL 옵티마이저는 인덱스 기수성/선택도 등을 무시하고 최대 N건만 읽으면 된다고 판단하게 된다.
  그러므로 이 값을 적게 설정할 수록 서버가 인덱스를 사용하도록 유도하는 효과가 있다.
```

#### ORDER BY 처리 
- Filesort 방식과 인덱스를 이용한 정렬 방식으로 나뉜다.
- 소트 버퍼 : 정렬을 수행하기 위해 따로 할당한 메모리 공간이다. 최대 사용 공간은 sort_buffer_size로 설정할 수 있으며 최적 크기는 trial 로 찾아봐야 한다.
        정렬할 데이터가 많지 않아 메모리에만 소트 버퍼가 잡히면 문제 없지만 데이터가 많아서 디스크를 써야하는 경우 정렬, 합성에 많은 리소스가 필요하게된다.
- 정렬 알고리즘 : 소트 버퍼에 모든 컬럼을 전부 담아 정렬하는 싱글 패스 알고리즘과, 정렬 대상 컬럼과 pkey만 소트 버퍼에 담아 정렬하고 정렬된 순서대로 다시 다른 컬럼을 채우는 투 패스 알고리즘이 있다.
        레코드 건수가 작은 경우 싱글 패스가 빠르나, 레코드 크기가 max_length_for_sort_data 를 넘어서거나 BLOB이나 TEXT타입 컬럼이 select 대상에 포함될 때 싱글패스를 사용하지 못하고 투패스가 사용된다. 
- 정렬의 처리 방식 : 인덱스 사용한 정렬 > 드라이빙 테이블만 정렬 후 조인 > 조인결과를 임시테이블로 저장한 후 임시테이블에서 정렬.
```mysql
# 인덱스를 이용한 정렬
# 반드시 정렬 기준 컬럼이 가장 먼저 읽는 테이블(조인이 쓰이는 경우 드라이빙 테이블)에 속하면서 인덱스가 있어야 한다.

explain
select * from employees e, salaries s
where s.emp_no=e.emp_no
and e.emp_no between 100002 and 100020
order by e.emp_no;
```
```mysql
# 드라이빙 테이블만 정렬
# 일반적으로 조인이 실행되면 테이블 건수가 불어나기 때문에, 조인이 실행되기 전에 첫번째 테이블 레코드를 먼저 정리하는 것이 낫다.
# 이 방법은 드라이빙 테이블 칼럼만으로 order by가 작성되어야 한다.
select * from employees e, salaries s
where s.emp_no=e.emp_no
and e.emp_no between 100002 and 100010
order by e.last_name;
```
```mysql
# 임시 테이블 이용한 정렬
# 2개 이상의 테이블을 조인해서 그 결과를 정렬한다면 임시 테이블이 필요할 수 있다.
# 아래 쿼리는 정렬 조건이 드리븐 테이블의 컬럼이므로 조인 후 정렬이 될 수 밖에 없다.
select * from employees e, salaries s
where s.emp_no=e.emp_no
  and e.emp_no between 100002 and 100010
order by s.salary;
``` 