### TODO

   1. Zapoznać się z treścią zadania i wykładami, dodać ważne rzeczy do readme. [DONE]
   2. Przygotować środowisko do pracy [DONE]
   3. Napisać wersje kodu:
    - program CPU (wersja nr.0) [DONE]
    - program GPU:
        - oryginalna bez zrównoleglenia pobierania i obliczeń (wersja nr.1) [DONE]
        - równoległe obliczenia i pobieranie do rejestrów (obliczenia jako pierwsze w kodzie) (wersja nr.2.1) [DONE]
        - równoległe obliczenia i pobieranie do rejestrów (pobieranie jako pierwsze w kodzie) (wersja nr.2.2) 
        - równoległe obliczenia i pobieranie do pamięci współdzielonej (obliczenia jako pierwsze w kodzie) (wersja nr.3.1)
        - równoległe obliczenia i pobieranie do pamięci współdzielonej (pobieranie jako pierwsze w kodzie) (wersja nr.3.1)     
        
   4. Przeprowadzić pomiary:
   - prędkość obliczeń uwzględniającą liczbę operacji zmiennoprzecinkowych wg złożoności algorytmu mnożenia macierzy o wielkości NxN, prędkość=2*N*N*N/T
   - przyspieszenie w stosunku do przetwarzania równoległego (openMP) za pomocą CPU
   - CGMA – obliczony podczas analizowania przebiegu przetwarzania
   - zajętość multiprocesora za pomocą CUDA Occupancy Calculator tool dostępnego w dystrybucji
        oprogramowania, przedstawiać przyczyny obniżonej wartości zajętości (wielkość instancji, liczba bloków,
        wymagania rejestrowe, wymagania na pamięć współdzieloną). Do wyznaczenia liczby rejestrów
        wykorzystywanych przez wątek proszę skorzystać z programu oceny efektywności przetwarzania NVIDIA
        Nsight Compute (lub NVIDIA Visual Profiler – starsza wersja oprogramowania CUDA)
   
   5. Napisać sprawozdanie

**Link do sprawozdania:**

https://docs.google.com/document/d/1QenbAFKOeuPfCbdnITtxZPFhRKgXexGmvBuDhFi3vUA/edit

**Link do dokumentu z pomiarami:**

https://docs.google.com/spreadsheets/d/1E0nMM_v_i6ml3umW_iR_QIGyi7LpoULKQxh34xT2E2E/edit#gid=0
